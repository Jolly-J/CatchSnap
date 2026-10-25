/**
 * @file: fluid_cloud_capsule.dart
 * @description: 流体云 (Fluid Cloud) 顶部灵动药丸胶囊状态条组件
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/constants.dart';
import '../services/fluid_cloud_service.dart';

class FluidCloudCapsule extends StatelessWidget {
  const FluidCloudCapsule({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FluidCloudState>(
      valueListenable: FluidCloudService.state,
      builder: (context, state, _) {
        if (!state.visible) {
          return const SizedBox.shrink();
        }

        final percent = (state.progress * 100).toInt();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E), // 灵动深黑胶囊底色
                borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 左侧咔捕状态吉祥物
                  Image.asset(
                    state.isCompleted
                        ? AppConstants.mascotSuccess
                        : state.isFailed
                            ? AppConstants.mascotSad
                            : AppConstants.mascotSprint,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),

                  // 中间标题与速度
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.title.isNotEmpty ? state.title : '流体云任务执行中',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.speedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 右侧百分比或操作
                  if (!state.isCompleted && !state.isFailed) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percent%',
                        style: const TextStyle(
                          color: AirbnbTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () => FluidCloudService.dismiss(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
