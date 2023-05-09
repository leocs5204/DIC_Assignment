from PIL import Image
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.transforms as T
from fxpmath import Fxp

img = Image.open('./images/ney.jpg')

# Read Original image size
width, height = img.size
print(width, height)
if width < height:
    sqrbound = width
else:
    sqrbound = height
# Setting the points for cropped image
left = 100
top = 0
right = sqrbound + left
bottom = sqrbound

imgcrop = img.crop((left, top, right, bottom))
imgcrop.save('./images/ney_crop.jpg')
# Image grayscaling
imgGray = imgcrop.convert('L')

newSize = (256, 256)
newImg = imgGray.resize(newSize)
newImg_arr = np.array(newImg)
newImg_arr32 = newImg_arr.astype(np.float32)
inputImage = torch.tensor(newImg_arr32)
print("\nInput Image: \n", inputImage)

# Convolution

kernel = torch.tensor([-0.0625, -0.125, -0.0625, -0.25, 1., -0.25, -
                      0.0625, -0.125, -0.0625]).reshape(3, 3).unsqueeze(0).unsqueeze(0)

bias = torch.tensor(-0.75).unsqueeze(0)
print("\nkernel:\n", kernel)
print("\nbias:\n", bias)

input = inputImage.unsqueeze(0).unsqueeze(0)

# Padding
m = nn.ReplicationPad2d(2)
pad_data = m(input)
print("\nPadding data result: \n", pad_data)

# Convolution
res = F.conv2d(pad_data, kernel, bias=bias, stride=1, padding=0, dilation=2)
print("\nConvolution result:\ ", res)
relu_data = F.relu(res)
print("\nRelu result: \n",  relu_data)

transform = T.ToPILImage()
l0_result = transform(relu_data.squeeze().squeeze())
l0_result.show()
l0_result.save('./images/ney_l0.jpg')

# MaxPooling
maxpoolRes = F.max_pool2d(relu_data, 2, stride=2, padding=0)
print("\nMaxPooling result: \n", maxpoolRes)
l1_result = transform(maxpoolRes.squeeze().squeeze())
l1_result.show()
l1_result.save('./images/ney_l1.jpg')
