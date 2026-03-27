<?php

namespace App\Helpers;

class PhoneHelper
{
    /**
     * Normalize a Palestinian phone number to international format (970XXXXXXXXX)
     * 
     * Handles multiple input formats:
     * - +970123456789
     * - 0123456789 (local format)
     * - 123456789 (without country code or 0)
     * - 970123456789 (country code already included)
     * 
     * @param string|null $number The phone number to normalize
     * @return string|null Normalized number in format 970XXXXXXXXX or null if invalid
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

        // If starts with 0, replace with 970 (Palestinian country code)
        if (str_starts_with($number, '0')) {
            $number = '970' . substr($number, 1);
        }

        // If doesn't start with 970, add it
        if (!str_starts_with($number, '970')) {
            $number = '970' . $number;
        }

        return $number;
    }

    /**
     * Validate if a normalized phone number is valid
     * Palestinian numbers should be 12 digits starting with 970
     * 
     * @param string|null $number The normalized phone number
     * @return bool True if valid
     */
    public static function isValid(?string $number): bool
    {
        if (empty($number)) {
            return false;
        }

        return (bool) preg_match('/^970\d{9}$/', $number);
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
