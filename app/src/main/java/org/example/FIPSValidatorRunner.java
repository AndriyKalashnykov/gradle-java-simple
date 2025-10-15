/*
 * FIPS Validator Runner - Runs all FIPSValidator methods
 */
package org.example;

public class FIPSValidatorRunner {

    public static void main(String[] args) {
        System.out.println("=== FIPS Validator Runner ===");
        System.out.println();

        FIPSValidator validator = new FIPSValidator();

        // Run isFIPSModeEnabled
        System.out.println("1. Checking if FIPS mode is enabled...");
        boolean fipsEnabled = validator.isFIPSModeEnabled();
        System.out.println("   Result: " + fipsEnabled);
        System.out.println();

        // Run getFIPSStatus
        System.out.println("2. Getting FIPS status...");
        String status = validator.getFIPSStatus();
        System.out.println("   Status: " + status);
        System.out.println();

        // Run printFIPSProviders
        System.out.println("3. Printing FIPS providers...");
        validator.printFIPSProviders();
        System.out.println();

        System.out.println("=== FIPS Validator Runner Complete ===");
    }
}
