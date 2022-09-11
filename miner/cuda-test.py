# This source code is a part of Project Violet.
# Copyright (C) 2022. violet-team. Licensed under the Apache-2.0 License.

import torch

# https://pakalguksu.github.io/development/Anaconda%EB%A1%9C-PyTorch-%EC%84%A4%EC%B9%98%ED%95%98%EA%B3%A0-GPU-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0/

print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))