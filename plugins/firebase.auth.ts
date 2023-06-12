import { initializeApp } from "firebase/app";

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional

export default defineNuxtPlugin((nuxtApp) => {
  const { firebaseConfig } = useRuntimeConfig();
  initializeApp(firebaseConfig);
});
