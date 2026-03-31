<?php

namespace App\Helpers;

class PhoneHelper
{
    /**
     * Normalize a phone number to international format (COUNTRYCODEXXXXXXXXXXX)
     * 
     * Handles multiple input formats:
     * - +1234567890 (with or without +)
     * - +1 123 456 7890 (with spaces and +)
     * - 0123456789 (Palestinian local format - converts to 970XXXXXXXXX)
     * - 123456789 (without country code - assumes Palestinian if 9 digits)
     * - 1234567890 (country code already included)
     * 
     * Special handling for Palestine (970) and Israel (972):
     * - Removes extra 0 after country code (e.g., 9700... → 970..., 9720... → 972...)
     * 
     * @param string|null $number The phone number to normalize
     * @return string|null Normalized number in international format or null if invalid
     */
    public static function normalize(?string $number): ?string
    {
        if (empty($number)) {
            return null;
        }

        // Remove all non-digit characters
        $number = (string) preg_replace('/[^0-9]/', '', $number);

        // If number is empty after removing non-digits
        if (empty($number)) {
            return null;
        }

        // If starts with 0 and has 10 digits (Palestinian local format)
        if (str_starts_with($number, '0') && strlen($number) === 10) {
            $number = '970' . substr($number, 1);
        }

        // If 9 digits without country code, assume Palestinian and add 970
        if (strlen($number) === 9) {
            $number = '970' . $number;
        }

        // Remove extra 0 after Palestinian (970) country code
        // e.g., 9700123456789 → 970123456789
        if (str_starts_with($number, '9700')) {
            $number = '970' . substr($number, 4);
        }

        // Remove extra 0 after Israeli (972) country code
        // e.g., 9720123456789 → 972123456789
        if (str_starts_with($number, '9720')) {
            $number = '972' . substr($number, 4);
        }

        return $number;
    }

    /**
     * Validate if a normalized phone number is valid
     * 
     * Palestinian (970) and Israeli (972): exactly 12 digits (country code + 9 digits)
     * Other countries: 11-15 digits
     * 
     * @param string|null $number The normalized phone number
     * @return bool True if valid
     */
    public static function isValid(?string $number): bool
    {
        if (empty($number)) {
            return false;
        }

        // Palestinian (970) or Israeli (972): must be 12 digits (970/972 + 9 digits)
        if (preg_match('/^(970|972)\d{9}$/', $number)) {
            return true;
        }

        // Other international formats: 11-15 digits
        return (bool) preg_match('/^\d{11,15}$/', $number);
    }

    /**
     * Format phone number for display
     * 
     * @param string|null $number The normalized phone number
     * @return string|null Formatted as +970 XXX XXX XXX or null if invalid
     */
    public static function format(?string $number): ?string
    {
        if (!self::isValid($number)) {
            return null;
        }

        return '+' . substr($number, 0, 3) . ' ' . substr($number, 3, 3) . ' ' . substr($number, 6, 3) . ' ' . substr($number, 9, 3);
    }

    /**
     * Get WhatsApp URL for a phone number
     * 
     * @param string|null $number The raw or normalized phone number
     * @param string $message Message to send
     * @return string|null WhatsApp URL or null if invalid
     */
    public static function getWhatsAppUrl(?string $number, string $message = ''): ?string
    {
        $normalized = self::normalize($number);

        if (!self::isValid($normalized)) {
            return null;
        }

        return 'https://wa.me/' . $normalized . '?text=' . rawurlencode($message);
    }
}
