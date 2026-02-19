// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// FAQ accordion: use turbo:load so it runs on first load and after every Turbo visit
function faqAccordionClick(e) {
  var btn = e.target.closest(".faq-item .faq-q");
  if (!btn) return;
  var item = btn.closest(".faq-item");
  var answer = document.getElementById(btn.getAttribute("aria-controls"));
  var isOpen = item.classList.toggle("is-open");
  btn.setAttribute("aria-expanded", isOpen);
  if (answer) answer.setAttribute("aria-hidden", !isOpen);
}

document.addEventListener("turbo:load", function() {
  document.removeEventListener("click", faqAccordionClick);
  document.addEventListener("click", faqAccordionClick);
});
