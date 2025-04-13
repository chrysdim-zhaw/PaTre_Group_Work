document.addEventListener("DOMContentLoaded", function () {
  const tocToggle = document.createElement("button");
  tocToggle.id = "toc-toggle";
  tocToggle.innerText = "TOC anzeigen";
  document.body.appendChild(tocToggle);

  tocToggle.addEventListener("click", function () {
    document.body.classList.toggle("show-toc");
    tocToggle.innerText = document.body.classList.contains("show-toc")
      ? "TOC ausblenden"
      : "TOC anzeigen";
  });
});
