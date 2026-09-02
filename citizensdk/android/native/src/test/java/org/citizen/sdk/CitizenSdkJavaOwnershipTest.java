package org.citizen.sdk;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import org.junit.Test;

public final class CitizenSdkJavaOwnershipTest {
  @Test
  public void operationExposesCorrelationAndCancelButNoCoreHandle() throws Exception {
    Method cancel = CitizenSdkOperation.class.getMethod("cancel");
    Method operationId = CitizenSdkOperation.class.getMethod("getOperationId");
    assertNotNull(cancel);
    assertNotNull(operationId);
    assertTrue(
        java.util.Arrays.stream(CitizenSdkOperation.class.getMethods())
            .noneMatch(method -> method.getName().toLowerCase().contains("handle")));
  }

  @Test
  public void secretAndHandleEntrypointsAreNotJavaSourceApi() throws Exception {
    assertTrue(
        java.util.Arrays.stream(CitizenSdk.class.getDeclaredMethods())
            .filter(
                method ->
                    Modifier.isPublic(method.getModifiers())
                        && (method.getName().contains("prepareWalletCreation")
                            || method.getName().contains("importWallet")
                            || method.getName().contains("addWalletAccounts")
                            || method.getName().contains("commitPreparedWallet")))
            .allMatch(Method::isSynthetic));

    ClassLoader loader = CitizenSdkJavaOwnershipTest.class.getClassLoader();
    Class<?> nativeOwner =
        Class.forName("org.citizen.sdk.internal.CitizenSdkNative", false, loader);
    assertTrue(
        java.util.Arrays.stream(nativeOwner.getDeclaredConstructors())
            .allMatch(
                constructor ->
                    Modifier.isPrivate(constructor.getModifiers()) || constructor.isSynthetic()));
    Class<?> prepared =
        Class.forName("org.citizen.sdk.CitizenSdkPreparedWallet", false, loader);
    assertTrue(
        java.util.Arrays.stream(prepared.getDeclaredConstructors())
            .allMatch(
                constructor ->
                    Modifier.isPrivate(constructor.getModifiers()) || constructor.isSynthetic()));

    Class<?> coordinator =
        Class.forName("org.citizen.sdk.ui.CitizenSdkWalletFlowCoordinator", false, loader);
    assertTrue(
        java.util.Arrays.stream(coordinator.getDeclaredMethods())
            .filter(
                method ->
                    Modifier.isPublic(method.getModifiers())
                        && (method.getName().contains("acceptPreparation")
                            || method.getName().contains("settlePrepared")
                            || method.getName().contains("retryPreparedRelease")))
            .allMatch(Method::isSynthetic));
  }
}
