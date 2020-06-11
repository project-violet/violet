// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

// Implementation of distance functions that satisfy trigonometry.

class Distance {

  static int hammingDistance<T>(List<T> l1, List<T> l2) {
    if (l1.length != l2.length)
      return -1;
      
    int result = 0;
    for (int i =0; i <l1.length; i++)
      if (l1[i] != l2[i])
        result++;

    return result;
  }

}