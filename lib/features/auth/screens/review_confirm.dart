import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/screens/client/dashboard.dart';

class ReviewConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> allData;

  const ReviewConfirmScreen({super.key, required this.allData});

  @override
  State<ReviewConfirmScreen> createState() => _ReviewConfirmScreenState();
}

class _ReviewConfirmScreenState extends State<ReviewConfirmScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color textGrey = Color(0xFF64748B);
  static const Color darkBlue = Color(0xFF334155);

  bool isLoading = false;

  Future<void> _handleSave() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user session found. Please log in again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => isLoading = false);
        return;
      }

      await Supabase.instance.client.from('user_profiles').upsert({
        'id': user.id,
        'full_name': widget.allData['full_name'],
        'phone': widget.allData['phone'],
        'age': widget.allData['age'],
        'gender': widget.allData['gender'],
        'height_cm': widget.allData['height_cm'],
        'weight_kg': widget.allData['weight_kg'],
        'diet': widget.allData['diet'],
        'taste': widget.allData['taste'],
        'allergen': widget.allData['allergen'],
        'food_restriction': widget.allData['food_restriction'],
        'calorie_target': widget.allData['calorie_target'],
        'weight_goal': widget.allData['weight_goal'],
        'target_weight': widget.allData['target_weight'],
        'activity_level': widget.allData['activity_level'],
        'protein_goal_g': widget.allData['protein_goal_g'],
        'carbs_goal_g': widget.allData['carbs_goal_g'],
        'fat_goal_g': widget.allData['fat_goal_g'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const SuccessSequenceDialog();
          },
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database Error: ${e.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  String _fmt(dynamic val) => val?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    final d = widget.allData;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Step 4 of 4 – Review & Confirm',
          style: TextStyle(
            color: darkBlue,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const SizedBox(height: 10),

            _buildReviewSection(
              title: 'Personal Information',
              children: [
                _buildReviewRow('Full Name', _fmt(d['full_name'])),
                _buildReviewRow('Phone', _fmt(d['phone'])),
                _buildReviewRow(
                  'Age / Gender',
                  '${_fmt(d['age'])} / ${_fmt(d['gender'])}',
                ),
                _buildReviewRow(
                  'Height / Weight',
                  '${_fmt(d['height_cm'])} cm / ${_fmt(d['weight_kg'])} kg',
                ),
              ],
            ),

            _buildReviewSection(
              title: 'Preferences & Restrictions',
              children: [
                _buildReviewRow('Diet', _fmt(d['diet'])),
                _buildReviewRow('Taste', _fmt(d['taste'])),
                _buildReviewRow('Allergens', _fmt(d['allergen'])),
                _buildReviewRow('Avoid', _fmt(d['food_restriction'])),
              ],
            ),

            _buildReviewSection(
              title: 'Nutritional Goals',
              children: [
                _buildReviewRow(
                  'Calorie Target',
                  '${_fmt(d['calorie_target'])} kcal/day',
                ),
                _buildReviewRow('Goal', _fmt(d['weight_goal'])),
                _buildReviewRow(
                  'Target Weight',
                  '${_fmt(d['target_weight'])} kg',
                ),
                _buildReviewRow('Activity', _fmt(d['activity_level'])),
                _buildReviewRow(
                  'Macros (P / C / F)',
                  '${_fmt(d['protein_goal_g'])}g / ${_fmt(d['carbs_goal_g'])}g / ${_fmt(d['fat_goal_g'])}g',
                ),
              ],
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Save & Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Divider(height: 30),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: textGrey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Success Dialog ────────────────────────────────────────────────────────────

class SuccessSequenceDialog extends StatefulWidget {
  const SuccessSequenceDialog({super.key});

  @override
  State<SuccessSequenceDialog> createState() => _SuccessSequenceDialogState();
}

class _SuccessSequenceDialogState extends State<SuccessSequenceDialog> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final navigator = Navigator.of(context, rootNavigator: true);

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isLoading = false);

        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            navigator.pop(); // Close the dialog
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
              (route) => false,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF67A75F),
          strokeWidth: 4,
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF67A75F),
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              'Information Saved!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text(
              'Your details have been successfully saved. Taking you to your dashboard now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
