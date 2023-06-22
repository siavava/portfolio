/**
 * Removes trailing slash from path
 * @param path
 * @returns string representing the path without trailing slash
 */
export default () => {
  const { path: rawPath } = useRoute();

  // avoid trimming the index route.
  if (rawPath === "/") return { path: rawPath };

  // remove trailing slash
  const path = rawPath.endsWith("/") ? rawPath.slice(0, -1) : rawPath;
  return { path };
};
