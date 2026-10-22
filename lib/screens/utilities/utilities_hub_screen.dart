import 'package:flutter/material.dart';
import 'camera_translator_screen.dart';
import 'location_share_screen.dart';
import 'noise_meter_screen.dart';

class UtilitiesHubScreen extends StatelessWidget {
  const UtilitiesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Tiện Ích & AI Thực Tế'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade800, Colors.deepPurple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.shade900.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.stars_rounded, color: Colors.yellowAccent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Chức Năng Thuyết Trình & Sáng Tạo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bao gồm các tiện ích thông minh đồng bộ cùng hệ thống Web API.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // DANH SÁCH TIỆN ÍCH
              const Text(
                'Chức Năng Tiện Ích',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              // 1. Đo tiếng ồn
              _buildFeatureCard(
                context,
                title: '1. Đo Tiếng Ồn (Noise Meter)',
                subtitle: 'Đo cường độ âm thanh Decibel (dB) thời gian thực, biểu đồ sóng âm, cảnh báo mức ồn và lưu vào API.',
                icon: Icons.graphic_eq_rounded,
                accentColor: Colors.tealAccent,
                tag: 'Decibel (dB)',
                targetScreen: const NoiseMeterScreen(),
              ),

              const SizedBox(height: 12),

              // 2. Chia sẻ vị trí
              _buildFeatureCard(
                context,
                title: '2. Chia Sẻ Vị Trí (Location GPS)',
                subtitle: 'Xác định tọa độ GPS, tra cứu địa chỉ thực tế, hiển thị radar định vị vệ tinh, chia sẻ Zalo/SMS & lưu API.',
                icon: Icons.explore_rounded,
                accentColor: Colors.cyanAccent,
                tag: 'GPS & Map',
                targetScreen: const LocationShareScreen(),
              ),

              const SizedBox(height: 12),

              // 3. Dịch tiếng Anh realtime bằng camera
              _buildFeatureCard(
                context,
                title: '3. Dịch Tiếng Anh Bằng Camera',
                subtitle: 'Quét camera trực tiếp, nhận diện chữ tiếng Anh trên biển hiệu, dịch sang tiếng Việt theo thời gian thực.',
                icon: Icons.camera_alt_rounded,
                accentColor: Colors.amberAccent,
                tag: 'Live OCR Lens',
                targetScreen: const CameraTranslatorScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String tag,
    required Widget targetScreen,
    bool isHighlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? Colors.purpleAccent : Colors.white12,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => targetScreen),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
