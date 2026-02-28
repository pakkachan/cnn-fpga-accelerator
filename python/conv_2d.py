import numpy as np
from scipy import signal

# Simple conv2d just to see what convolution looks like
def conv_2d(image, kernel, stride = 1):
    result = signal.convolve2d(image, kernel, "valid")[::stride, ::stride]
    return result

if __name__ == "__main__":
    kernel = [[1,2,3],
            [4,5,6],
            [7,8,9]]

    kernel = np.flip(kernel)

    image = [[1,2,3,4],
            [5,6,7,8],
            [9,10,11,12],
            [13,14,15,16]]
    print(kernel)
    print(conv_2d(image, kernel))


