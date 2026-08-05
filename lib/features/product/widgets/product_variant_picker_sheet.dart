import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';

Future<ProductVariant?> showProductVariantPickerSheet(
  BuildContext context, {
  required String productName,
  required List<ProductVariant> variants,
}) {
  return showModalBottomSheet<ProductVariant>(
    context: context,
    backgroundColor: AppColors.containerBgColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final safeBottom = MediaQuery.of(context).padding.bottom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: variants.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: AppColors.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final variant = variants[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        variant.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppColors.primaryTextColor,
                      ),
                      onTap: () => Navigator.of(context).pop(variant),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
