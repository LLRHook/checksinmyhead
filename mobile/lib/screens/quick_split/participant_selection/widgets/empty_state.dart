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

import 'package:flutter/material.dart';

/// A visually appealing empty state widget displaying when no participants are added
/// Features a gradient circle with people icon and instructional text
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset('assets/images/billy.png', width: 150, height: 150),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 3),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Add friends to get started",
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
