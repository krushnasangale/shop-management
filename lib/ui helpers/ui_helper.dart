// Helper widget to create the label and input field block
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget buildInputField({
  required String label,
  required String hint,
  IconData? suffixIcon,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8.0),
      TextField(
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Icon(suffixIcon, color: Colors.grey[600]),
                )
              : null,
        ),
      ),
      const SizedBox(height: 24.0),
    ],
  );
}

Widget buildFormField(
  String hint,
  TextEditingController controller, {
  IconData? suffixIcon,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  Function()? onTap,
  Function(String)? onChanged,
  List<TextInputFormatter>? inputFormatters,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 53,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: TextFormField(
          onTap: onTap,
          onChanged: onChanged,
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            fillColor: Colors.white,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[700]!),
            filled: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: maxLines > 1 ? 16.0 : 16.0,
              horizontal: 16.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: Colors.grey[700]!)
                : null,
          ),
        ),
      ),
    ],
  );
}
