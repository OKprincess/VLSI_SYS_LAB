# -*- coding: utf-8 -*-
# Implementation by Gilles Van Assche, hereby denoted as "the implementer".
#
# For more information, feedback or questions, please refer to our website:
# https://keccak.team/
#
# To the extent possible under law, the implementer has waived all copyright
# and related or neighboring rights to the source code in this file.
# http://creativecommons.org/publicdomain/zero/1.0/

import os, inspect, bitstring, itertools

# def gen_vec(funcName, *vars):
#     current_frame   = inspect.currentframe()
#     caller_frame    = inspect.getouterframes(current_frame)[1]
#     local_vars      = caller_frame.frame.f_locals
#     for var in vars:
#         for name, value in local_vars.items():
#             if value is var:
#                 print(f'{name:20}: {var}')
#                 os.system(f'mkdir -p ./vec/{funcName}')
#                 with open(f'./vec/{funcName}/{name}.vec', 'a') as fh:
#                     fh.write(hex(var).replace('0x','').rjust(1184,'0')+'\n')
   
def genvec(funcName, dict, bitwidth):
    # bitwidth = bytelen *2 (since hex)
    for key, value in dict.items():
        print(f'{key:20}: {value}')
        os.system(f'mkdir -p ./vec/{funcName}')
        with open(f'./vec/{funcName}/{key}.vec', 'a') as fh:
            fh.write(hex(value).replace('0x','').rjust(bitwidth,'0')+'\n')   

def ROL64(a, n):
    out =  ((a >> (64-(n%64))) + (a << (n%64))) % (1 << 64)
    return out

def KeccakF1600onLanes(lanes):
    i_lanes = list(itertools.chain(*lanes))
    i_lanes = int(''.join(hex(x).replace('0x', '').rjust(16, '0') for x in i_lanes), 16)
    R = 1
    for round in range(24):
        # θ
        C = [lanes[x][0] ^ lanes[x][1] ^ lanes[x][2] ^ lanes[x][3] ^ lanes[x][4] for x in range(5)]
        D = [C[(x+4)%5] ^ ROL64(C[(x+1)%5], 1) for x in range(5)]
        lanes = [[lanes[x][y]^D[x] for y in range(5)] for x in range(5)]

        # ρ and π
        (x, y) = (1, 0)
        current = lanes[x][y]
        for t in range(24):
            (x, y) = (y, (2*x+3*y)%5)
            (current, lanes[x][y]) = (lanes[x][y], ROL64(current, (t+1)*(t+2)//2))

        # χ
        for y in range(5):
            T = [lanes[x][y] for x in range(5)]
            for x in range(5):
                lanes[x][y] = T[x] ^((~T[(x+1)%5]) & T[(x+2)%5])

        # ι
        for j in range(7):
            R = ((R << 1) ^ ((R >> 7)*0x71)) % 256
            if (R & 2):
                lanes[0][0] = lanes[0][0] ^ (1 << ((1<<j)-1))

    return lanes

def load64(b):
    out = sum((b[i] << (8*i)) for i in range(8))
    #i_data = int.from_bytes(b)
    #gen_vec('load64', i_data, out)
    return out

def store64(a):
    out = list((a >> (8*i)) % 256 for i in range(8))
    o_out = int(''.join(hex(x).replace('0x', '').rjust(2, '0') for x in out), 16)
    #gen_vec('store64', a, o_out)
    return out

def KeccakF1600(state):

    # i_istate = int.from_bytes(state)

    lanes = [[load64(state[8*(x+5*y):8*(x+5*y)+8]) for y in range(5)] for x in range(5)]
    lanes = KeccakF1600onLanes(lanes)
    state = bytearray(200)
    for x in range(5):
        for y in range(5):
            state[8*(x+5*y):8*(x+5*y)+8] = store64(lanes[x][y])

    # # """for test"""
    # o_ostate = int.from_bytes(state)
    # print(f'[KeccakF1600] iState  : {hex(i_istate).replace("0x", "")}')
    # print(f'[KeccakF1600] oState  : {hex(o_ostate).replace("0x", "")}')

    # vecDict = dict()
    # vecDict['i_istate'] = i_istate
    # vecDict['o_ostate'] = o_ostate
    # genvec('keccakf1600', vecDict, 200*2)

    return state

def Keccak(rate, capacity, inputBytes, delimitedSuffix, outputByteLen):

    """for test"""
    print('==============================')
    if rate == 1344:
        print(f'SHAKE128: IOBytes={len(inputBytes)},{outputByteLen}')
        i_mode = 0
    if rate == 1088 and delimitedSuffix == 0x1F:
        print(f'SHAKE256: IOBytes={len(inputBytes)},{outputByteLen}')
        i_mode = 1
    if rate == 1088 and delimitedSuffix == 0x06:
        print(f'SHA3_256: IOBytes={len(inputBytes)},{outputByteLen}')
        i_mode = 2
    if rate == 576:
        print(f'SHA3_512: IOBytes={len(inputBytes)},{outputByteLen}')
        i_mode = 3
    print('==============================')
    """for test"""

    outputBytes = bytearray()
    state = bytearray([0 for i in range(200)])
    rateInBytes = rate//8
    blockSize = 0
    inputOffset = 0

    # ===================================
    # === Absorb all the input blocks ===
    # ===================================
    while(inputOffset < len(inputBytes)):
        # HW-FETCH
        blockSize = min(len(inputBytes)-inputOffset, rateInBytes)
        
        # HW-ABSB
        for i in range(blockSize):
            state[i] = state[i] ^ inputBytes[i+inputOffset]
        print(f'[ABSB  ]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')       
        inputOffset = inputOffset + blockSize

        # HW-ABSB-KECCAK
        if (blockSize == rateInBytes):
            state = KeccakF1600(state)
            print(f'[ABSB_K]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')
            blockSize = 0

    # ========================================================
    # === Do the padding and switch to the squeezing phase ===
    # ========================================================
    print(f'[PADD_I]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')
    state[blockSize] = state[blockSize] ^ delimitedSuffix

    # This part is not needed for Kyber
    # if (((delimitedSuffix & 0x80) != 0) and (blockSize == (rateInBytes-1))):
    #    state = KeccakF1600(state)
    #    print(f'[Padding]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}')
    #    k = k+1

    state[rateInBytes-1] = state[rateInBytes-1] ^ 0x80
    print(f'[PADD  ]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')
    state = KeccakF1600(state)
    print(f'[PADD_K]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')

    # =========================================
    # === Squeeze out all the output blocks ===
    # =========================================
    while(outputByteLen > 0):
        blockSize = min(outputByteLen, rateInBytes)
        outputBytes = outputBytes + state[0:blockSize]
        outputByteLen = outputByteLen - blockSize
        print(f'[SQUZ  ]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')
        if (outputByteLen > 0):
            print(f'[SQUZ_K]: BlockSize={blockSize}, IOBytes={len(inputBytes)},{outputByteLen}, State={state.hex()}')
            state = KeccakF1600(state)


    """for test"""
    if len(inputBytes) % 8 == 0:
        i_ibytes = int(int.from_bytes(inputBytes, byteorder='big'))
    else:
        i_ibytes = int(int.from_bytes(inputBytes, byteorder='big') << 8*(8 - (len(inputBytes) % 8))) 
    o_obytes = int(int.from_bytes(outputBytes, byteorder='big'))

    print(f'[keccak] IBytes  : {hex(i_ibytes).replace("0x", "")}')
    print(f'[keccak] OBytes  : {hex(o_obytes).replace("0x", "")}')

    vecDict = dict()
    vecDict['i_ibytes']     = i_ibytes
    vecDict['o_obytes']     = o_obytes
    vecDict['i_ibytes_len'] = len(inputBytes)
    vecDict['i_obytes_len'] = len(outputBytes)
    vecDict['i_mode']       = i_mode

    genvec('keccak', vecDict, 1568*2)
    
    return outputBytes


def SHAKE128(inputBytes, outputByteLen):
    return Keccak(1344, 256, inputBytes, 0x1F, outputByteLen)

def SHAKE256(inputBytes, outputByteLen):
    return Keccak(1088, 512, inputBytes, 0x1F, outputByteLen)

def SHA3_224(inputBytes):
    return Keccak(1152, 448, inputBytes, 0x06, 224//8)

def SHA3_256(inputBytes):
    return Keccak(1088, 512, inputBytes, 0x06, 256//8)

def SHA3_384(inputBytes):
    return Keccak(832, 768, inputBytes, 0x06, 384//8)

def SHA3_512(inputBytes):
    return Keccak(576, 1024, inputBytes, 0x06, 512//8)
