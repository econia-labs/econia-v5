import math

def get_L(b_r, q_r):
    d = (q_r ** 2) + \
        (b_r ** 2) * (sqrt_p_h ** 2) * (sqrt_p_l ** 2) + \
        2 * b_r * q_r * sqrt_p_h * (2 * sqrt_p_h - sqrt_p_l)
    numerator = q_r + b_r * sqrt_p_h * sqrt_p_l + math.sqrt(d)
    denominator = 2 * (sqrt_p_h - sqrt_p_l)
    return numerator / denominator

def get_b_r(L, q_r):
    return ((L ** 2) * (sqrt_p_h - sqrt_p_l) - L * q_r) / \
        (sqrt_p_h * (q_r + L * sqrt_p_l))

def get_q_r(L, b_r):
    return ((L ** 2) * (sqrt_p_h - sqrt_p_l) - L * b_r * sqrt_p_h * sqrt_p_l) / \
    (b_r * sqrt_p_h + L)

def get_sqrt_p(L, b_r, q_r):
    return math.sqrt((sqrt_p_h * (q_r + L * sqrt_p_l)) / (b_r * sqrt_p_h + L))

sqrt_p_l = 10.0
sqrt_p_h = 20.0
b_r = 200.0
q_r = 5000.0
L = get_L(b_r, q_r)

print(f"sqrt_p_h: {sqrt_p_h}, sqrt_p_l: {sqrt_p_l}")
print(f"Initial b_r: {b_r}, q_r: {q_r}")

print(f"Resultant liquidity L: {L}")
print(f"b_r from L and q_r: {get_b_r(L, q_r)}")
print(f"q_r from L and b_r: {get_q_r(L, b_r)}")
print(f"sqrt_p from L, b_r, and q_r: {get_sqrt_p(L, b_r, q_r)}")
