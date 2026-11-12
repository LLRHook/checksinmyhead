// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/animation.dart';

/// Custom curve for a bouncy entrance (easeOutBack style)
class BouncyEntranceCurve extends Curve {
  @override
  double transformInternal(double t) {
    // easeOutBack: overshoots slightly then settles at 1.0
    // Maps 0.0 → 0.0 and 1.0 → 1.0 as required by Flutter
    const s = 1.70158;
    final p = 1.0 - t;
    return 1.0 - p * p * ((s + 1) * p - s);
  }
}
