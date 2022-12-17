// Element Observer
export default function observe() {

  // ignore in ssr mode (when window is undefined)
  if (typeof window !== 'undefined') {

    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.remove("hidden");
        } else {
          entry.target.classList.add("hidden");
        }
      });
    });
  
    const hiddenElements = document.querySelectorAll(".hide");
    hiddenElements.forEach((element) => observer.observe(element));
  }
}
