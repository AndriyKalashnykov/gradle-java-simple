/*
 * Integration test for FIPSValidatorRunner: spawns a real JVM subprocess
 * and verifies stdout contract + exit code under different system-property flags.
 */
package org.example;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class FIPSValidatorRunnerIT {

  private static String runRunner(List<String> jvmArgs) throws Exception {
    String javaBin = System.getProperty("java.home") + "/bin/java";
    String classpath = System.getProperty("java.class.path");

    List<String> cmd = new ArrayList<>();
    cmd.add(javaBin);
    cmd.addAll(jvmArgs);
    cmd.add("-cp");
    cmd.add(classpath);
    cmd.add("org.example.FIPSValidatorRunner");

    ProcessBuilder pb = new ProcessBuilder(cmd);
    pb.redirectErrorStream(true);
    Process p = pb.start();

    StringBuilder out = new StringBuilder();
    try (BufferedReader r =
        new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
      String line;
      while ((line = r.readLine()) != null) {
        out.append(line).append('\n');
      }
    }
    if (!p.waitFor(30, TimeUnit.SECONDS)) {
      p.destroyForcibly();
      fail("Runner subprocess timed out. Output:\n" + out);
    }
    assertEquals(0, p.exitValue(), "Runner exited non-zero. Output:\n" + out);
    return out.toString();
  }

  @Test
  @DisplayName("Runner prints all three sections and reports ENABLED when FIPS flag is set")
  void runnerWithFipsFlag() throws Exception {
    String output =
        runRunner(
            List.of("-Dsemeru.fips=true", "-Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"));

    assertTrue(output.contains("=== FIPS Validator Runner ==="), output);
    assertTrue(output.contains("1. Checking if FIPS mode is enabled..."), output);
    assertTrue(output.contains("2. Getting FIPS status..."), output);
    assertTrue(output.contains("3. Printing FIPS providers..."), output);
    assertTrue(output.contains("Status: FIPS mode is ENABLED"), output);
    assertTrue(output.contains("Security Providers:"), output);
    assertTrue(output.contains("=== FIPS Validator Runner Complete ==="), output);
  }

  @Test
  @DisplayName("Runner reports DISABLED when FIPS flag is explicitly false")
  void runnerWithoutFipsFlag() throws Exception {
    String output = runRunner(List.of("-Dsemeru.fips=false"));

    assertTrue(output.contains("Status: FIPS mode is DISABLED"), output);
    assertTrue(output.contains("Security Providers:"), output);
    assertTrue(output.contains("=== FIPS Validator Runner Complete ==="), output);
  }

  @Test
  @DisplayName("Runner detects FIPS via customprofile alone")
  void runnerWithCustomProfileOnly() throws Exception {
    String output =
        runRunner(
            List.of("-Dsemeru.fips=false", "-Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"));

    assertTrue(output.contains("Status: FIPS mode is ENABLED"), output);
  }
}
