# 
# Number-theoretic transform library (Python)
# 
# Copyright (c) 2025 Project Nayuki
# All rights reserved. Contact Nayuki for licensing.
# https://www.nayuki.io/page/number-theoretic-transform-integer-dft
# 

import itertools


# ---- High-level NTT functions ----

# Finds an appropriate set of parameters for the NTT, computes the forward transform on
# the given vector, and returns a tuple containing the output vector and NTT parameters.
# Note that all input values must be integers in the range [0, minmod).
def find_params_and_transform(invec: list[int], minmod: int) -> tuple[list[int],int,int]:
	mod: int = find_modulus(len(invec), minmod)
	root: int = find_primitive_root(len(invec), mod - 1, mod)
	return (transform(invec, root, mod), root, mod)


# Returns the forward number-theoretic transform of the given vector with
# respect to the given primitive nth root of unity under the given modulus.
def transform(invec: list[int], root: int, mod: int) -> list[int]:
	if len(invec) >= mod:
		raise ValueError()
	if not all((0 <= val < mod) for val in invec):
		raise ValueError()
	if not (1 <= root < mod):
		raise ValueError()
	
	outvec: list[int] = []
	for i in range(len(invec)):
		temp: int = 0
		for (j, val) in enumerate(invec):
			temp += val * pow(root, i * j, mod)
			temp %= mod
		outvec.append(temp)
	return outvec


# Returns the inverse number-theoretic transform of the given vector with
# respect to the given primitive nth root of unity under the given modulus.
def inverse_transform(invec: list[int], root: int, mod: int) -> list[int]:
	outvec: list[int] = transform(invec, pow(root, -1, mod), mod)
	scaler: int = pow(len(invec), -1, mod)
	return [(val * scaler % mod) for val in outvec]


# Computes the forward number-theoretic transform of the given vector in place,
# with respect to the given primitive nth root of unity under the given modulus.
# The length of the vector must be a power of 2.
def transform_radix_2(vector: list[int], root: int, mod: int) -> None:
	n: int = len(vector)
	levels: int = n.bit_length() - 1
	if 1 << levels != n:
		raise ValueError("Length is not a power of 2")
	
	def reverse(x: int, bits: int) -> int:
		y: int = 0
		for i in range(bits):
			y = (y << 1) | (x & 1)
			x >>= 1
		return y
	for i in range(n):
		j: int = reverse(i, levels)
		if j > i:
			vector[i], vector[j] = vector[j], vector[i]
	
	powtable: list[int] = []
	temp: int = 1
	for i in range(n // 2):
		powtable.append(temp)
		temp = temp * root % mod
	
	size: int = 2
	while size <= n:
		halfsize: int = size // 2
		tablestep: int = n // size
		for i in range(0, n, size):
			k: int = 0
			for j in range(i, i + halfsize):
				l: int = j + halfsize
				left: int = vector[j]
				right: int = vector[l] * powtable[k]
				vector[j] = (left + right) % mod
				vector[l] = (left - right) % mod
				k += tablestep
		size *= 2


# Returns the circular convolution of the given vectors of integers.
# All values must be non-negative. Internally, a sufficiently large modulus
# is chosen so that the convolved result can be represented without overflow.
def circular_convolve(vec0: list[int], vec1: list[int]) -> list[int]:
	if not (0 < len(vec0) == len(vec1)):
		raise ValueError()
	if any((val < 0) for val in itertools.chain(vec0, vec1)):
		raise ValueError()
	maxval: int = max(val for val in itertools.chain(vec0, vec1))
	minmod: int = maxval**2 * len(vec0) + 1
	temp0, root, mod = find_params_and_transform(vec0, minmod)
	temp1: list[int] = transform(vec1, root, mod)
	temp2: list[int] = [(x * y % mod) for (x, y) in zip(temp0, temp1)]
	return inverse_transform(temp2, root, mod)



# ---- Mid-level number theory functions for NTT ----

# Returns the smallest modulus mod such that mod = i * veclen + 1
# for some integer i >= 1, mod > veclen, and mod is prime.
# Although the loop might run for a long time and create arbitrarily large numbers,
# Dirichlet's theorem guarantees that such a prime number must exist.
def find_modulus(veclen: int, minimum: int) -> int:
	if veclen < 1 or minimum < 1:
		raise ValueError()
	start: int = (minimum - 1 + veclen - 1) // veclen
	for i in itertools.count(max(start, 1)):
		n: int = i * veclen + 1
		assert n >= minimum
		if is_prime(n):
			return n
	raise AssertionError("Unreachable")


# Returns an arbitrary primitive degree-th root of unity modulo mod.
# totient must be a multiple of degree. If mod is prime, an answer must exist.
def find_primitive_root(degree: int, totient: int, mod: int) -> int:
	if not (1 <= degree <= totient < mod):
		raise ValueError()
	if totient % degree != 0:
		raise ValueError()
	gen: int = find_generator(totient, mod)
	root: int = pow(gen, totient // degree, mod)
	assert 0 <= root < mod
	return root


# Returns an arbitrary generator of the multiplicative group of integers modulo mod.
# totient must equal the Euler phi function of mod. If mod is prime, an answer must exist.
def find_generator(totient: int, mod: int) -> int:
	if not (1 <= totient < mod):
		raise ValueError()
	for i in range(1, mod):
		if is_primitive_root(i, totient, mod):
			return i
	raise ValueError("No generator exists")


# Tests whether val is a primitive degree-th root of unity modulo mod.
# In other words, val^degree % mod = 1, and for each 1 <= k < degree, val^k % mod != 1.
# 
# To test whether val generates the multiplicative group of integers modulo mod,
# set degree = totient(mod), where totient is the Euler phi function.
# We say that val is a generator modulo mod if and only if the set of numbers
# {val^0 % mod, val^1 % mod, ..., val^(totient-1) % mod} is equal to the set of all
# numbers in the range [0, mod) that are coprime to mod. If mod is prime, then
# totient = mod - 1, and powers of a generator produces all integers in the range [1, mod).
def is_primitive_root(val: int, degree: int, mod: int) -> bool:
	if not (0 <= val < mod):
		raise ValueError()
	if not (1 <= degree < mod):
		raise ValueError()
	pf: list[int] = unique_prime_factors(degree)
	return pow(val, degree, mod) == 1 and \
		all((pow(val, degree // p, mod) != 1) for p in pf)



# ---- Low-level common number theory functions ----

# Returns a list of unique prime factors of the given integer in
# ascending order. For example, unique_prime_factors(60) = [2, 3, 5].
def unique_prime_factors(n: int) -> list[int]:
	if n < 1:
		raise ValueError()
	result: list[int] = []
	i: int = 2
	end: int = sqrt(n)
	while i <= end:
		if n % i == 0:
			n //= i
			result.append(i)
			while n % i == 0:
				n //= i
			end = sqrt(n)
		i += 1
	if n > 1:
		result.append(n)
	return result


# Tests whether the given integer n >= 2 is a prime number.
def is_prime(n: int) -> bool:
	if n <= 1:
		raise ValueError()
	return all((n % i != 0) for i in range(2, sqrt(n) + 1))


# Returns floor(sqrt(n)) for the given integer n >= 0.
def sqrt(n: int) -> int:
	if n < 0:
		raise ValueError()
	i: int = 1
	while i * i <= n:
		i *= 2
	result: int = 0
	while i > 0:
		if (result + i)**2 <= n:
			result += i
		i //= 2
	return result






# 
# Free FFT and convolution (Python)
# 
# Copyright (c) 2020 Project Nayuki. (MIT License)
# https://www.nayuki.io/page/free-small-fft-in-multiple-languages
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# - The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
# - The Software is provided "as is", without warranty of any kind, express or
#   implied, including but not limited to the warranties of merchantability,
#   fitness for a particular purpose and noninfringement. In no event shall the
#   authors or copyright holders be liable for any claim, damages or other
#   liability, whether in an action of contract, tort or otherwise, arising from,
#   out of or in connection with the Software or the use or other dealings in the
#   Software.
# 

import cmath


# 
# Computes the discrete Fourier transform (DFT) or inverse transform of the given complex vector, returning the result as a new vector.
# The vector can have any length. This is a wrapper function. The inverse transform does not perform scaling, so it is not a true inverse.
# 
def transform(vec, inverse):
	n = len(vec)
	if n == 0:
		return []
	elif n & (n - 1) == 0:  # Is power of 2
		return transform_radix2(vec, inverse)
	else:  # More complicated algorithm for arbitrary sizes
		return transform_bluestein(vec, inverse)


# 
# Computes the discrete Fourier transform (DFT) of the given complex vector, returning the result as a new vector.
# The vector's length must be a power of 2. Uses the Cooley-Tukey decimation-in-time radix-2 algorithm.
# 
def transform_radix2(vec, inverse):
	# Returns the integer whose value is the reverse of the lowest 'width' bits of the integer 'val'.
	def reverse_bits(val, width):
		result = 0
		for _ in range(width):
			result = (result << 1) | (val & 1)
			val >>= 1
		return result
	
	# Initialization
	n = len(vec)
	levels = n.bit_length() - 1
	if 2**levels != n:
		raise ValueError("Length is not a power of 2")
	# Now, levels = log2(n)
	coef = (2 if inverse else -2) * cmath.pi / n
	exptable = [cmath.rect(1, i * coef) for i in range(n // 2)]
	vec = [vec[reverse_bits(i, levels)] for i in range(n)]  # Copy with bit-reversed permutation
	
	# Radix-2 decimation-in-time FFT
	size = 2
	while size <= n:
		halfsize = size // 2
		tablestep = n // size
		for i in range(0, n, size):
			k = 0
			for j in range(i, i + halfsize):
				temp = vec[j + halfsize] * exptable[k]
				vec[j + halfsize] = vec[j] - temp
				vec[j] += temp
				k += tablestep
		size *= 2
	return vec


# 
# Computes the discrete Fourier transform (DFT) of the given complex vector, returning the result as a new vector.
# The vector can have any length. This requires the convolution function, which in turn requires the radix-2 FFT function.
# Uses Bluestein's chirp z-transform algorithm.
# 
def transform_bluestein(vec, inverse):
	# Find a power-of-2 convolution length m such that m >= n * 2 + 1
	n = len(vec)
	if n == 0:
		return []
	m = 2**((n * 2).bit_length())
	
	coef = (1 if inverse else -1) * cmath.pi / n
	exptable = [cmath.rect(1, (i * i % (n * 2)) * coef) for i in range(n)]  # Trigonometric table
	avec = [(x * y) for (x, y) in zip(vec, exptable)] + [0] * (m - n)  # Temporary vectors and preprocessing
	bvec = exptable[ : n] + [0] * (m - (n * 2 - 1)) + exptable[ : 0 : -1]
	bvec = [x.conjugate() for x in bvec]
	cvec = convolve(avec, bvec, False)[ : n]  # Convolution
	return [(x * y) for (x, y) in zip(cvec, exptable)]  # Postprocessing


# 
# Computes the circular convolution of the given real or complex vectors, returning the result as a new vector. Each vector's length must be the same.
# realoutput=True: Extract the real part of the convolution, so that the output is a list of floats. This is useful if both inputs are real.
# realoutput=False: The output is always a list of complex numbers (even if both inputs are real).
# 
def convolve(xvec, yvec, realoutput=True):
	assert len(xvec) == len(yvec)
	n = len(xvec)
	xvec = transform(xvec, False)
	yvec = transform(yvec, False)
	for i in range(n):
		xvec[i] *= yvec[i]
	xvec = transform(xvec, True)
	
	# Scaling (because this FFT implementation omits it) and postprocessing
	if realoutput:
		return [(val.real / n) for val in xvec]
	else:
		return [(val / n) for val in xvec]