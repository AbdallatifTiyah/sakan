import 'package:flutter/material.dart';
import '../theme.dart';

/// خطوة ١ من ٤ بمسار "أضف شقتك" — سؤال وحدة بالشاشة (المدينة) بدل فورم طويل
/// يخوّف المالك من أول ثانية. باقي الخطوات (التفاصيل، الصور، المرافق) لاحقاً.
class AddListingStep1Screen extends StatefulWidget {
  const AddListingStep1Screen({super.key});

  @override
  State<AddListingStep1Screen> createState() => _AddListingStep1ScreenState();
}

class _AddListingStep1ScreenState extends State<AddListingStep1Screen> {
  String? _city;
  final _cities = const ['رام الله', 'البيرة', 'بيرزيت'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('أضف شقتك'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepProgress(step: 1, total: 4),
              const SizedBox(height: 28),
              const Text(
                'وين شقتك؟',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SColors.navy),
              ),
              const SizedBox(height: 8),
              const Text(
                'سؤال واحد بس عشان نبدأ — باقي التفاصيل بالخطوات الجاية.',
                style: TextStyle(color: SColors.mut, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 28),
              ..._cities.map((city) {
                final selected = city == _city;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SRadius.md),
                    onTap: () => setState(() => _city = city),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        color: selected ? SColors.blue050 : SColors.card,
                        borderRadius: BorderRadius.circular(SRadius.md),
                        border: Border.all(
                          color: selected ? SColors.blue600 : SColors.line,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected ? SColors.blue600 : SColors.mut,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: SColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              SPrimaryButton(
                label: 'التالي',
                icon: Icons.arrow_back,
                onPressed: _city == null
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تجريبي — باقي الخطوات لسا ما انبنت')),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int step, total;
  const _StepProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == total - 1 ? 0 : 6),
            height: 5,
            decoration: BoxDecoration(
              color: active ? SColors.blue600 : SColors.line,
              borderRadius: BorderRadius.circular(SRadius.pill),
            ),
          ),
        );
      }),
    );
  }
}
