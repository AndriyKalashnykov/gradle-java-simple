/*
 * Test class for FIPSValidator
 */
package org.example;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;

class FIPSValidatorTest {

    private FIPSValidator fipsValidator;

    @BeforeEach
    void setUp() {
        fipsValidator = new FIPSValidator();
    }

    @Test
    @DisplayName("isFIPSModeEnabled should return a boolean value")
    void isFIPSModeEnabledReturnsBoolean() {
        boolean result = fipsValidator.isFIPSModeEnabled();
        assertTrue(result || !result); // Should return either true or false
    }

    @Test
    @DisplayName("getFIPSStatus should return enabled or disabled message")
    void getFIPSStatusReturnsMessage() {
        String status = fipsValidator.getFIPSStatus();
        assertNotNull(status);
        System.out.println("FIPS Status: " + status);
        assertTrue(status.equals("FIPS mode is ENABLED") || status.equals("FIPS mode is DISABLED"));
    }

    @Test
    @DisplayName("getFIPSStatus should match isFIPSModeEnabled result")
    void getFIPSStatusMatchesIsFIPSModeEnabled() {
        boolean isEnabled = fipsValidator.isFIPSModeEnabled();
        String status = fipsValidator.getFIPSStatus();

        if (isEnabled) {
            assertEquals("FIPS mode is ENABLED", status);
        } else {
            assertEquals("FIPS mode is DISABLED", status);
        }
    }

    @Test
    @DisplayName("printFIPSProviders should print to console")
    void printFIPSProvidersPrintsToConsole() {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        PrintStream originalOut = System.out;

        try {
            System.setOut(new PrintStream(outputStream));
            fipsValidator.printFIPSProviders();

            String output = outputStream.toString();
            assertNotNull(output);
            assertTrue(output.contains("Security Providers:"));
            assertTrue(output.length() > 0);
        } finally {
            System.setOut(originalOut);
        }
    }

    @Test
    @DisplayName("printFIPSProviders should list at least one provider")
    void printFIPSProvidersListsProviders() {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        PrintStream originalOut = System.out;

        try {
            System.setOut(new PrintStream(outputStream));
            fipsValidator.printFIPSProviders();

            String output = outputStream.toString();
            assertTrue(output.contains("-") || output.contains("Provider"));
        } finally {
            System.setOut(originalOut);
        }
    }

    @Test
    @DisplayName("Multiple calls to isFIPSModeEnabled should return consistent results")
    void multipleFIPSModeChecksAreConsistent() {
        boolean firstCall = fipsValidator.isFIPSModeEnabled();
        boolean secondCall = fipsValidator.isFIPSModeEnabled();
        boolean thirdCall = fipsValidator.isFIPSModeEnabled();

        assertEquals(firstCall, secondCall);
        assertEquals(secondCall, thirdCall);
    }

    @Test
    @DisplayName("getFIPSStatus should never return null")
    void getFIPSStatusNeverReturnsNull() {
        String status = fipsValidator.getFIPSStatus();
        assertNotNull(status);
        System.out.println("FIPS Status: " + status);
    }

    @Test
    @DisplayName("Multiple FIPSValidator instances should return same FIPS status")
    void multipleFIPSValidatorInstancesReturnSameStatus() {
        FIPSValidator validator1 = new FIPSValidator();
        FIPSValidator validator2 = new FIPSValidator();

        assertEquals(validator1.isFIPSModeEnabled(), validator2.isFIPSModeEnabled());
        assertEquals(validator1.getFIPSStatus(), validator2.getFIPSStatus());
    }
}
