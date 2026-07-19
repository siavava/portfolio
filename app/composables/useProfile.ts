const query = () => queryCollection("profile").first()

export const useProfile = () => useAsyncData("profile", query)
