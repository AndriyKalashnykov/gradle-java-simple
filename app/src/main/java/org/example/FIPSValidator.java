/*
 * FIPS Validator - Validates and reports FIPS mode status
 */
package org.example;

import java.security.Security;
import java.security.Provider;

public class FIPSValidator {

    public boolean isFIPSModeEnabled() {
        // Check Semeru JDK FIPS system properties
        String semeruFipsProp = System.getProperty("semeru.fips");
        System.out.println("Semeru FIPS property: " + semeruFipsProp);
        if ("true".equalsIgnoreCase(semeruFipsProp)) {
            return true;
        }

        // Check Semeru custom profile for FIPS
        String semeruCustomProfile = System.getProperty("semeru.customprofile");
        System.out.println("Semeru custom profile: " + semeruCustomProfile);
        if (semeruCustomProfile != null && semeruCustomProfile.contains("FIPS")) {
            return true;
        }

        // Check if FIPS mode is enabled by examining security properties
        String fipsProperty = Security.getProperty("crypto.policy");
        System.out.println("FIPS property: " + fipsProperty);
        if (fipsProperty != null && fipsProperty.contains("unlimited")) {
            // Additional check: Look for FIPS provider
            for (Provider provider : Security.getProviders()) {
                String providerName = provider.getName().toLowerCase();
                if (providerName.contains("fips")) {
                    return true;
                }
            }
        }

        // Check Red Hat FIPS system property
        String fipsSystemProp = System.getProperty("com.redhat.fips");
        if ("true".equalsIgnoreCase(fipsSystemProp)) {
            return true;
        }

        // Check if any FIPS provider is registered
        for (Provider provider : Security.getProviders()) {
            if (provider.getName().toLowerCase().contains("fips")) {
                return true;
            }
        }

        return false;
    }

    public String getFIPSStatus() {
        if (isFIPSModeEnabled()) {
            return "FIPS mode is ENABLED";
        } else {
            return "FIPS mode is DISABLED";
        }
    }

    public void printFIPSProviders() {
        System.out.println("Security Providers:");
        for (Provider provider : Security.getProviders()) {
            System.out.println("  - " + provider.getName() + " (v" + provider.getVersion() + ")");
            if (provider.getName().toLowerCase().contains("fips")) {
                System.out.println("    [FIPS Provider Detected]");
            }
        }
    }
}
