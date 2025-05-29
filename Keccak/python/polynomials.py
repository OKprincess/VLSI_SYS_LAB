import random, itertools, os
from bitstring import Bits
from utils import *
from fixedpoint import FixedPoint

def genvec(funcName, dict, bitwidth):
    for key, value in dict.items():
        print(f'{key:20}: {value}')
        os.system(f'mkdir -p ./vec/{funcName}')
        with open(f'./vec/{funcName}/{key}.vec', 'a') as fh:
            fh.write(hex(value).replace('0x','').rjust(bitwidth,'0')+'\n')   

class PolynomialRing:
    """
    Initialise the polynomial ring:
        
        R = GF(q) / (X^n + 1) 
    """
    def __init__(self, q, n, ntt_helper=None):
        self.q = q # The finite field size
        self.n = n # The degree of the polynomial
        self.element = PolynomialRing.Polynomial # A polynomial class instance
        self.ntt_helper = ntt_helper # An optional helper class for performing Number Theoretic Transforms (NTT)

    # Generates a polynomial with coefficients [0, 1]. 
    # The "is_ntt" parameter specifies whether the polynomial should be in NTT form.
    def gen(self, is_ntt=False):
        return self([0,1], is_ntt=is_ntt) # use __call__ method -> Polynomial

    # Generates a random polynomial with coefficients in the range [0, q-1]. 
    # The "is_ntt" parameter specifies whether the polynomial should be in NTT form.
    def random_element(self, is_ntt=False):
        coefficients = [random.randint(0, self.q - 1) for _ in range(self.n)]

        return self(coefficients, is_ntt=is_ntt) # use __call__ method -> Polynomial
        
    # Convert a byte stream to the NTT representation with q = 3329 (Parses a byte array into a polynomial)
    # It extracts coefficients from the byte array and creates a polynomial.
    def parse(self, input_bytes, is_ntt=False):
        """
        Algorithm 1 (Parse)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Parse: B^* -> R
        """
        i, j = 0, 0
        coefficients = [0 for _ in range(self.n)]
        while j < self.n:
            #print(f'while loop {j}')
            d1 = input_bytes[i] + 256*(input_bytes[i+1] % 16)
            d2 = (input_bytes[i+1] // 16) + 16*input_bytes[i+2]
            
            if d1 < self.q:
                #print(f'[PARSE - {j, i}] d1: {d1}')
                coefficients[j] = d1
                j = j + 1
            
            if d2 < self.q and j < self.n:
                #print(f'[PARSE - {j, i}] d2: {d2}')
                coefficients[j] = d2
                j = j + 1
                
            i = i + 3

        """
        For Test
        """
        self.parse_input_bytes = input_bytes
        self.parse_coefficients = coefficients
        self.parse_return = self(coefficients, is_ntt=is_ntt)

        # print(f'[PARSE] Input Bytes  : {len(input_bytes)},{input_bytes.hex()}')
        # print(f'[PARSE] COEFF        : {[hex(x).replace('0x','') for x in coefficients]}')
        # print(f'[PARSE] MIN/MAX COEFF: {min(coefficients)},{max(coefficients)}')
        # print(f'[PARSE] Return       : {self(coefficients, is_ntt=is_ntt)}')

        # vecDict = dict()
        # vecDict['i_ibytes'] = int.from_bytes(input_bytes)
        # vecDict['o_coeffs'] = int(''.join(Bits(uint=x, length=12).bin for x in coefficients), 2)
        # genvec('parse', vecDict, 768*2)

        return self(coefficients, is_ntt=is_ntt)      

    # Performs Centered Binomial Distribution (CBD) on a byte array and converts it into a polynomial. 
    # This is used in the Kyber algorithm to generate random polynomials.
    def cbd(self, input_bytes, eta, is_ntt=False):
        """
        Algorithm 2 (Centered Binomial Distribution)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Expects a byte array of length (eta * polynomial_degree / 4) ~ eta * (polynomial_degree >> 2)
        For Kyber, this is 64 eta.
        """
        assert (self.n >> 2)*eta == len(input_bytes) # Ensure that input are 64 bytes long
        coefficients = [0 for _ in range(self.n)]
        list_of_bits = bytes_to_bits(input_bytes) # Convert 64 bytes to 512 bits
        for i in range(self.n):
            a = sum(list_of_bits[2*i*eta + j]       for j in range(eta))
            b = sum(list_of_bits[2*i*eta + eta + j] for j in range(eta))
            #print(f'eta: {eta}, 2*i*eta: {2*i*eta}')
            coefficients[i] = a-b

        """
        For Test
        """
        self.cbd_input_bytes = input_bytes
        self.cbd_eta = eta
        self.cbd_coefficients = coefficients
        self.cbd_list_of_bits = list_of_bits
        self.cbd_return = self(coefficients, is_ntt=is_ntt)

        # print(f'[CBD] Input Bytes  : {len(input_bytes)},{input_bytes.hex()}')
        # print(f'[CBD] ETA          : {eta}')
        # print(f'[CBD] COEFF        : {coefficients}')
        # print(f'[CBD] MIN/MAX COEFF: {min(coefficients)},{max(coefficients)}')
        # print(f'[CBD] List of Bit  : {list_of_bits}')
        # print(f'[CBD] Return       : {self(coefficients, is_ntt=is_ntt)}')

        # vecDict = dict()
        # vecDict['i_ibytes'] = int.from_bytes(input_bytes)
        # vecDict['i_eta'] = int(eta)
        # vecDict['o_coeffs'] = int(''.join(Bits(int=x, length=3).bin for x in coefficients), 2)
        # genvec('cbd', vecDict, 192*2)

        return self(coefficients, is_ntt=is_ntt)
        
    # Decodes a byte array into a polynomial. 
    # This is used for decoding in Kyber.
    def decode(self, input_bytes, l=None, is_ntt=False):
        """
        Decode (Algorithm 3)
        
        decode: B^32l -> R_q
        """
        if l is None:
            l, check = divmod(8*len(input_bytes), self.n)
            if check != 0:
                raise ValueError("Input bytes must be a multiple of (polynomial degree) / 8")
        else:
            if self.n*l != len(input_bytes)*8:
                raise ValueError("Input bytes must be a multiple of (polynomial degree) / 8")
            
            
        coefficients = [0 for _ in range(self.n)]
        list_of_bits = bytes_to_bits(input_bytes)
        for i in range(self.n):
            coefficients[i] = sum(list_of_bits[i*l + j] << j for j in range(l))

        """For Test"""
        self.decode_input_bytes = input_bytes
        self.decode_l = l
        self.decode_coefficients = coefficients
        self.decode_list_of_bits = list_of_bits
        self.decode_return = self(coefficients, is_ntt=is_ntt)

        # print(f'[DECODE] Input Bytes  : {len(input_bytes)},{input_bytes.hex()}')
        # print(f'[DECODE] L            : {l}')
        # print(f'[DECODE] COEFF        : {coefficients}')
        # print(f'[DECODE] MIN/MAX COEFF: {min(coefficients)},{max(coefficients)}')
        # print(f'[DECODE] List of Bit  : {list_of_bits}')
        # print(f'[DECODE] Return       : {self(coefficients, is_ntt=is_ntt)}')

        # vecDict = dict()
        # vecDict['i_ibytes'] = int.from_bytes(input_bytes)
        # vecDict['i_l'] = int(l)
        # vecDict['o_coeffs'] = int(''.join(Bits(uint=x, length=l).bin for x in coefficients), 2)
        # genvec('decode', vecDict, 384*8//4)

        return self(coefficients, is_ntt=is_ntt)
            
    def __call__(self, coefficients, is_ntt=False):
        if isinstance(coefficients, int):
            return self.element(self, [coefficients], is_ntt)
        if not isinstance(coefficients, list):
            raise TypeError(f"Polynomials should be constructed from a list of integers, of length at most d = {self.n}")
        
        return self.element(self, coefficients, is_ntt) # Call the __init__ method of Polynomial

    # Define how instances of PolynomialRing are represented as strings when using the repr() function
    def __repr__(self):
        return f"Univariate Polynomial Ring in x over Finite Field of size {self.q} with modulus x^{self.n} + 1"

    class Polynomial:
        def __init__(self, parent, coefficients, is_ntt=False):
            self.parent = parent # An instance of PolynomialRing class
            self.coeffs = self.parse_coefficients(coefficients) # Coefficients in a polynomial
            self.is_ntt = is_ntt # Is polynomial in NTT form or not

        # Check whether that all coefficients are zero or not
        def is_zero(self):
            """
            Return if polynomial is zero: f = 0
            """
            return all(c == 0 for c in self.coeffs)

        # Check whether the polynomial is a 0 degree (There is just a constant) or not
        def is_constant(self):
            """
            Return if polynomial is constant: f = c
            """
            return all(c == 0 for c in self.coeffs[1:])
            
        # Add more "0" coefficients to the polynomial ~ Add "0" padding
        def parse_coefficients(self, coefficients):
            """
            Helper function which right pads with zeros
            to allow polynomial construction as 
            f = R([1,1,1])
            """
            l = len(coefficients)
            if l > self.parent.n:
                raise ValueError(f"Coefficients describe polynomial of degree greater than maximum degree {self.parent.n}")
            elif l < self.parent.n:
                coefficients = coefficients + [0 for _ in range (self.parent.n - l)]

            return coefficients
            
        # Reduce all coefficients value by mod q with each coefficient
        def reduce_coefficents(self):
            """
            Reduce all coefficents modulo q
            """
            self.coeffs = [c % self.parent.q for c in self.coeffs]

            return self
 
        # Encodes the polynomial as a byte array
        def encode(self, l=None):
            """
            Encode (Inverse of Algorithm 3)
            """
            if l is None:
                l = max(x.bit_length() for x in self.coeffs)

            # Reversed Bits for each coefficient
            bit_string = ''.join(format(c, f'0{l}b')[::-1] for c in self.coeffs)

            """
            For Test
            """
            self.encode_l = l
            self.encode_coefficients = self.coeffs
            self.encode_bit_string = bit_string

            # print(f'[ENCODE] L            : {l}')
            # print(f'[ENCODE] COEFF        : {self.coeffs}')
            # print(f'[ENCODE] MIN/MAX COEFF: {min(self.coeffs)},{max(self.coeffs)}')
            # print(f'[ENCODE] BIS_STRING   : {len(bit_string)},{bit_string}')
            # print(f'[ENCODE] Return       : {len(bitstring_to_bytes(bit_string))},{bitstring_to_bytes(bit_string).hex()}')
            # print(f'-----------------------------------------------------------')

            # vecDict = dict()
            # vecDict['i_coeffs'] = int(''.join(Bits(uint=x, length=12).bin for x in self.coeffs), 2)
            # vecDict['i_l'] = int(l)
            # vecDict['o_obytes'] = int.from_bytes(bitstring_to_bytes(bit_string))
            # genvec('encode', vecDict, 384*8//4)
            
            # Split 8-bit & reverse
            return bitstring_to_bytes(bit_string)

        # Compresses the polynomial coefficients using lossy compression
        def compress(self, d):
            """
            Compress the polynomial by compressing each coefficent
            NOTE: This is lossy compression
            """
            # print(f'[  COMPRESS] COEFF_ORIG   : {self.coeffs}')
            # print(f'[  COMPRESS] MIN/MAX COEFF: {min(self.coeffs)},{max(self.coeffs)}')

            i_coeffs = int(''.join(Bits(int=x, length=13).bin for x in self.coeffs), 2)
            frac_bits = 24

            compress_mod   = 2**d
            compress_float = compress_mod / self.parent.q
            compress_float = float(FixedPoint(compress_float, signed=False, m=0, n=frac_bits))

            hw_coeffs = list()

            for coeff in self.coeffs:
                mult = FixedPoint(compress_float * coeff, signed=True, m=13, n=frac_bits)
                mult_round = FixedPoint(mult.bits[frac_bits+12:frac_bits] + mult.bits[frac_bits-1])
                if d == 1:
                    hw_coeffs.append(mult_round.bits[0])
                else:
                    hw_coeffs.append(mult_round.bits[d-1:0])
                     
            self.coeffs = [round_up(compress_float * c) % compress_mod for c in self.coeffs]

            if hw_coeffs != self.coeffs:
                raise ValueError("TT")
            
            """
            For Test
            """
            self.compress_d = d
            self.compress_q = self.parent.q
            self.compress_float = compress_float
            self.compress_coefficients = self.coeffs

            # print(f'[  COMPRESS] D/Q          : {d}/{self.parent.q}')
            # print(f'[  COMPRESS] MOD/FLOAT    : {compress_mod}/{compress_float}')
            # print(f'[  COMPRESS] COEFF        : {self.coeffs}')
            # print(f'[  COMPRESS] HW-COEFF     : {hw_coeffs}')

            # print(f'[  COMPRESS] MIN/MAX COEFF: {min(self.coeffs)},{max(self.coeffs)}')

            # vecDict = dict()
            # vecDict['i_coeffs'] = i_coeffs
            # vecDict['i_d'] = d
            # vecDict['o_coeffs'] = int(''.join(Bits(uint=x, length=13).bin for x in self.coeffs), 2)
            # genvec('compress', vecDict, 13*256//4)

            return self
            
        # Decompresses the polynomial coefficients
        def decompress(self, d):
            """
            Decompress the polynomial by decompressing each coefficent
            NOTE: This as compression is lossy, we have
            x' = decompress(compress(x)), which x' != x, but is 
            close in magnitude.
            """

            # print(f'[DECOMPRESS] COEFF_ORIG   : {self.coeffs}')
            # print(f'[DECOMPRESS] MIN/MAX ORI_C: {min(self.coeffs)},{max(self.coeffs)}')
            i_coeffs = int(''.join(Bits(uint=x, length=12).bin for x in self.coeffs), 2)


            decompress_float = self.parent.q / 2**d
            decompress_float = float(FixedPoint(decompress_float, signed=False, m=11, n=3))


            hw_coeffs = list()
            for coeff in self.coeffs:
                mult = FixedPoint(decompress_float * coeff, signed=False, m=22, n=3)
                hw_coeffs.append(FixedPoint(mult.bits[14:3] + mult.bits[2]))
                     
            self.coeffs = [round_up(decompress_float * c) for c in self.coeffs]

            
            if hw_coeffs != self.coeffs:
                raise ValueError("TT")
            

            # """
            # For Test
            # """
            # self.decompress_d = d
            # self.decompress_q = self.parent.q
            # self.decompress_float = decompress_float
            # self.decompress_coefficients = self.coeffs

            # print(f'[DECOMPRESS] D/Q          : {d}/{self.parent.q}')
            # print(f'[DECOMPRESS] FLOAT        : {decompress_float}')
            # print(f'[DECOMPRESS] COEFF        : {self.coeffs}')
            # print(f'[DECOMPRESS] MIN/MAX COEFF: {min(self.coeffs)},{max(self.coeffs)}')

            # vecDict = dict()
            # vecDict['i_coeffs'] = i_coeffs
            # vecDict['i_d'] = d
            # vecDict['o_coeffs'] = int(''.join(Bits(uint=x, length=12).bin for x in self.coeffs), 2)
            # genvec('decompress', vecDict, 12*256//4)

            return self

        # Add two coefficents and then modulo q
        def add_mod_q(self, x, y):
            """
            add two coefficents modulo q
            """
            tmp = x + y
            if tmp >= self.parent.q:
                tmp -= self.parent.q

            return tmp

        # Subtract two coefficents and then modulo q
        def sub_mod_q(self, x, y):
            """
            sub two coefficents modulo q
            """
            tmp = x - y
            if tmp < 0:
                tmp += self.parent.q

            return tmp
            
        # An implementation of polynomial multiplication using the schoolbook multiplication algorithm. 
        # This algorithm is suitable for polynomial rings over finite fields, particularly for rings of the form R_q = F_1[X]/(X^n + 1), where F_1 represents a finite field.
        def schoolbook_multiplication(self, other):
            """
            Naive implementation of polynomial multiplication
            suitable for all R_q = F_1[X]/(X^n + 1)
            """
            n = self.parent.n
            a = self.coeffs
            b = other.coeffs
            new_coeffs = [0 for _ in range(n)]

            for i in range(n):
                for j in range(0, n-i):
                    new_coeffs[i+j] += (a[i] * b[j])

            for j in range(1, n):
                for i in range(n-j, n):
                    new_coeffs[i+j-n] -= (a[i] * b[j])

            return [c % self.parent.q for c in new_coeffs]
        
        """
        The next four `Polynomial` methods rely on the parent
        `PolynomialRing` having a `ntt_helper` from 
        ntt_helper.py and are used for NTT speediness.
        """
        # Converts a polynomial to Number Theoretic Transform (NTT) form
        def to_ntt(self):
            if self.parent.ntt_helper is None:
                raise ValueError("Can only perform NTT transform when parent element has an NTT Helper")
            
            return self.parent.ntt_helper.to_ntt(self)
        
        # Converts a polynomial from NTT form and performs a multiplication by a Montgomery factor
        def from_ntt(self):
            if self.parent.ntt_helper is None:
                raise ValueError("Can only perform NTT transform when parent element has an NTT Helper")
            
            return self.parent.ntt_helper.from_ntt(self)
            
        # Converts the coefficients of a polynomial "poly" to Montgomery form
        def to_montgomery(self):
            """
            Multiply every element by 2^16 mod q
            
            Only implemented (currently) for n = 256
            """
            if self.parent.ntt_helper is None:
                raise ValueError("Can only perform Mont. reduction when parent element has an NTT Helper")
            
            return self.parent.ntt_helper.to_montgomery(self)
        
        # Multiplies two sets of polynomial coefficients "f_coeffs" and "g_coeffs" using NTT-based multiplication
        def ntt_multiplication(self, other):
            """
            Number Theoretic Transform multiplication.
            Only implemented (currently) for n = 256
            """
            if self.parent.ntt_helper is None:
                raise ValueError("Can only perform ntt reduction when parent element has an NTT Helper")
            
            if not (self.is_ntt and other.is_ntt):
                raise ValueError("Can only multiply using NTT if both polynomials are in NTT form")
            
            # function in ntt_helper.py
            new_coeffs = self.parent.ntt_helper.ntt_coefficient_multiplication(self.coeffs, other.coeffs)

            return self.parent(new_coeffs, is_ntt=True)

        # Returns the negation of the polynomial. Behave like 0 - polynomial ~ -polynomial
        def __neg__(self):
            """
            Returns -f, by negating all coefficients
            """
            neg_coeffs = [(-x % self.parent.q) for x in self.coeffs]
            
            return self.parent(neg_coeffs, is_ntt=self.is_ntt)

        # Returns the sum of the self and other polynomials. Behave like self_polynomial + other_polynomial
        def __add__(self, other):
            if isinstance(other, PolynomialRing.Polynomial):
                if self.is_ntt ^ other.is_ntt:                    
                    raise ValueError(f"Both or neither polynomials must be in NTT form before multiplication")
                new_coeffs = [self.add_mod_q(x,y) for x,y in zip(self.coeffs, other.coeffs)]
            elif isinstance(other, int):
                new_coeffs = self.coeffs.copy()
                new_coeffs[0] = self.add_mod_q(new_coeffs[0], other)
            else:
                raise NotImplementedError(f"Polynomials can only be added to each other")
            
            return self.parent(new_coeffs, is_ntt=self.is_ntt)

        # Returns the sum of the self polynomial (in the right side of +) and another operand (in the left side of +). Behave like other_operand + self_polynomial
        def __radd__(self, other):
            return self.__add__(other)

        # Returns the sum of the self and other polynomials. Behave like self_polynomial += other_polynomial
        def __iadd__(self, other):
            self = self + other

            return self

        # Returns the difference of the self and other polynomials. Behave like self_polynomial - other_polynomial
        def __sub__(self, other):
            if isinstance(other, PolynomialRing.Polynomial):
                if self.is_ntt ^ other.is_ntt:
                    raise ValueError(f"Both or neither polynomials must be in NTT form before multiplication")
                new_coeffs = [self.sub_mod_q(x,y) for x,y in zip(self.coeffs, other.coeffs)]
            elif isinstance(other, int):
                new_coeffs = self.coeffs.copy()
                new_coeffs[0] = self.sub_mod_q(new_coeffs[0], other)
            else:
                raise NotImplementedError(f"Polynomials can only be subracted from each other")
            
            return self.parent(new_coeffs, is_ntt=self.is_ntt)

        # Returns the subtraction of the self polynomial (in the right side of -) and another operand (in the left side of -). Behave like other_operand - self_polynomial
        def __rsub__(self, other):
            return self.__sub__(other)

        # Returns the difference of the self and other polynomials. Behave like self_polynomial -= other_polynomial
        def __isub__(self, other):
            self = self - other

            return self

        # Returns the product of the self and other polynomials. Behave like self_polynomial * other_polynomial
        def __mul__(self, other):
            if isinstance(other, PolynomialRing.Polynomial):
                if self.is_ntt and other.is_ntt:
                    return self.ntt_multiplication(other)
                elif self.is_ntt ^ other.is_ntt:
                     raise ValueError(f"Both or neither polynomials must be in NTT form before multiplication")
                else:
                    new_coeffs = self.schoolbook_multiplication(other)
            elif isinstance(other, int):
                new_coeffs = [(c * other) % self.parent.q for c in self.coeffs]
            else:
                raise NotImplementedError(f"Polynomials can only be multiplied by each other, or scaled by integers")
            
            return self.parent(new_coeffs, is_ntt=self.is_ntt)

        # Returns the product of the self polynomial (in the right side of *) and another operand (in the left side of *). Behave like other_operand * self_polynomial
        def __rmul__(self, other):
            return self.__mul__(other)

        # Returns the product of the self and other polynomials. Behave like self_polynomial *= other_polynomial
        def __imul__(self, other):
            self = self * other
            return self

        # Define exponentiation behavior for a polynomial instance
        def __pow__(self, n):
            if not isinstance(n, int):
                raise TypeError(f"Exponentiation of a polynomial must be done using an integer.")

            # Deal with negative scalar multiplication
            if n < 0:
                raise ValueError(f"Negative powers are not supported for elements of a Polynomial Ring")
            
            f = self
            g = self.parent(1, is_ntt=self.is_ntt)
            while n > 0:
                if n % 2 == 1:
                    g = g * f
                f = f * f
                n = n // 2

            return g

        # Define the equality (==) comparison between polynomial instances
        def __eq__(self, other):
            if isinstance(other, PolynomialRing.Polynomial):
                return self.coeffs == other.coeffs and self.is_ntt == other.is_ntt
            elif isinstance(other, int):
                if self.is_constant() and (other % self.parent.q) == self.coeffs[0]:
                    return True
                
            return False

        # Allow you to access the coefficients of the polynomial using indexing (e.g., polynomial[0], polynomial[1], ...)
        def __getitem__(self, idx):
            return self.coeffs[idx]

        # Define how instances of Polynomial are represented as strings when using the repr() function
        def __repr__(self):
            ntt_info = ""

            if self.is_ntt:
                ntt_info = " (NTT form)"

            if self.is_zero():
                return "0" + ntt_info

            info = []
            for i,c in enumerate(self.coeffs):
                if c != 0:
                    if i == 0:
                        info.append(f"{c}")
                    elif i == 1:
                        if c == 1:
                            info.append("x")
                        else:
                            info.append(f"{c}*x")
                    else:
                        if c == 1:
                            info.append(f"x^{i}")
                        else:
                            info.append(f"{c}*x^{i}")
                            
            return " + ".join(info) + ntt_info

        # Define how instances of Polynomial are represented as strings when using the str() function
        def __str__(self):
            return self.__repr__()