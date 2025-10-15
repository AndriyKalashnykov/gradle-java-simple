import org.example.FIPSValidator;
import org.example.FIPSValidatorTest;
import java.lang.reflect.Method;

public class TestRunner {
    public static void main(String[] args) {
        System.out.println("=== FIPS Validator Test Runner ===");
        System.out.println("FIPS Mode: " + System.getProperty("semeru.fips"));
        System.out.println("FIPS Profile: " + System.getProperty("semeru.customprofile"));
        System.out.println();

        FIPSValidatorTest test = new FIPSValidatorTest();
        int passed = 0;
        int failed = 0;
        int total = 0;

        try {
            // Call setUp
            Method setUp = FIPSValidatorTest.class.getDeclaredMethod("setUp");
            setUp.setAccessible(true);

            // Get all test methods
            Method[] methods = FIPSValidatorTest.class.getDeclaredMethods();

            for (Method method : methods) {
                if (method.getName().startsWith("test") ||
                    method.isAnnotationPresent(org.junit.jupiter.api.Test.class)) {
                    total++;
                    System.out.print("Running: " + method.getName() + " ... ");
                    try {
                        setUp.invoke(test);
                        method.invoke(test);
                        System.out.println("PASSED");
                        passed++;
                    } catch (Exception e) {
                        System.out.println("FAILED");
                        System.out.println("  Error: " + e.getCause().getMessage());
                        failed++;
                    }
                }
            }

            System.out.println();
            System.out.println("=== Test Results ===");
            System.out.println("Total: " + total);
            System.out.println("Passed: " + passed);
            System.out.println("Failed: " + failed);

            if (failed > 0) {
                System.exit(1);
            }

        } catch (Exception e) {
            System.err.println("Test execution failed: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}
