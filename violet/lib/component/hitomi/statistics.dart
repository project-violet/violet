// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

class HitomiStatistics {
  static List<double> coff = [
    -4.2076842801467E-30,
    2.3640207921137E-23,
    5.064043805646E-17,
    5.0535353481094E-11,
    2.3551578350816E-05,
    9.0060003108906,
    327640.93204985
  ];

  // Valid for 9 ~ 1669507 (max +100000)
  // This method is only valid for monthly operations.
  static DateTime estimateDateTime(int id) {
    // var min = -4.2076842801467E-30 * id * id * id * id * id * id +
    //     2.3640207921137E-23 * id * id * id * id * id -
    //     5.064043805646E-17 * id * id * id * id +
    //     5.0535353481094E-11 * id * id * id -
    //     2.3551578350816E-05 * id * id +
    //     9.0060003108906 * id +
    //     327640.93204985;

    // var mm = (((((2.364020792114e-23 - 4.207684280147e-30 * id) * id -
    //                                     5.064043805646e-17) *
    //                                 id +
    //                             5.053535348109e-11) *
    //                         id -
    //                     0.00002355157835082) *
    //                 id +
    //             9.006000310891) *
    //         id +
    //     327640.93204985;

    var min = coff[0] * id * id * id * id * id * id +
        coff[1] * id * id * id * id * id -
        coff[2] * id * id * id * id +
        coff[3] * id * id * id -
        coff[4] * id * id +
        coff[5] * id +
        coff[6];

    return DateTime.fromMillisecondsSinceEpoch(1174358460000)
        .add(Duration(minutes: min.toInt()));
  }
}
