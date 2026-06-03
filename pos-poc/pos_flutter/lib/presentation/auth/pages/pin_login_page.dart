import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String _pin = '';
  final int _pinLength = 4;

  void _onNumberPressed(int number) {
    if (_pin.length < _pinLength) {
      setState(() => _pin += number.toString());
      if (_pin.length == _pinLength) _submitPin();
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty)
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submitPin() {
    context.read<AuthBloc>().add(AuthPinLoginRequested(pin: _pin));
  }

  void _clearPin() {
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pinLoginTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.error) {
            _clearPin();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? l10n.invalidPin),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.enterPin,
                    style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 32.h),

                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pinLength,
                      (index) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 8.w),
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _pin.length
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 48.h),

                  // Number pad
                  SizedBox(
                    width: 300.w,
                    child: Column(
                      children: [
                        for (int row = 0; row < 3; row++)
                          Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (int col = 1; col <= 3; col++)
                                  _buildNumberButton(row * 3 + col),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(width: 80.w),
                            _buildNumberButton(0),
                            _buildDeleteButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(40.r),
      child: Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider, width: 2),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return InkWell(
      onTap: _onDeletePressed,
      borderRadius: BorderRadius.circular(40.r),
      child: Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider, width: 2),
        ),
        child: Icon(Icons.backspace_outlined,
            size: 32.sp, color: AppColors.textSecondary),
      ),
    );
  }
}
