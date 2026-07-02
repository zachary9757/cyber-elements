const canvas = document.querySelector("#signal-canvas");
const ctx = canvas.getContext("2d");
const activeCode = document.querySelector("#active-code");
const activeDetail = document.querySelector("#active-detail");
const cards = Array.from(document.querySelectorAll(".element-card"));
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

const pointer = {
  x: window.innerWidth * 0.72,
  y: window.innerHeight * 0.38,
};

let particles = [];
let animationFrame = 0;

function resizeCanvas() {
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.floor(window.innerWidth * ratio);
  canvas.height = Math.floor(window.innerHeight * ratio);
  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  createParticles();
}

function createParticles() {
  const area = window.innerWidth * window.innerHeight;
  const count = reducedMotion.matches ? 28 : Math.min(92, Math.max(42, Math.floor(area / 18000)));

  particles = Array.from({ length: count }, (_, index) => ({
    x: Math.random() * window.innerWidth,
    y: Math.random() * window.innerHeight,
    vx: (Math.random() - 0.5) * 0.34,
    vy: (Math.random() - 0.5) * 0.34,
    size: index % 7 === 0 ? 2.2 : 1.3,
    tone: index % 3,
  }));
}

function drawNetwork() {
  ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);

  for (const point of particles) {
    if (!reducedMotion.matches) {
      point.x += point.vx;
      point.y += point.vy;
    }

    if (point.x < -20) point.x = window.innerWidth + 20;
    if (point.x > window.innerWidth + 20) point.x = -20;
    if (point.y < -20) point.y = window.innerHeight + 20;
    if (point.y > window.innerHeight + 20) point.y = -20;

    const pointerDistance = Math.hypot(point.x - pointer.x, point.y - pointer.y);
    const pull = Math.max(0, 1 - pointerDistance / 240);
    const x = point.x + (point.x - pointer.x) * pull * 0.035;
    const y = point.y + (point.y - pointer.y) * pull * 0.035;

    ctx.beginPath();
    ctx.fillStyle =
      point.tone === 0
        ? "rgba(255, 176, 0, 0.75)"
        : point.tone === 1
          ? "rgba(62, 231, 211, 0.68)"
          : "rgba(255, 77, 141, 0.48)";
    ctx.arc(x, y, point.size + pull * 2.2, 0, Math.PI * 2);
    ctx.fill();
  }

  for (let i = 0; i < particles.length; i += 1) {
    for (let j = i + 1; j < particles.length; j += 1) {
      const a = particles[i];
      const b = particles[j];
      const distance = Math.hypot(a.x - b.x, a.y - b.y);

      if (distance < 128) {
        const opacity = (1 - distance / 128) * 0.18;
        ctx.beginPath();
        ctx.strokeStyle = `rgba(239, 232, 209, ${opacity})`;
        ctx.lineWidth = 1;
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.stroke();
      }
    }
  }

  if (!reducedMotion.matches) {
    animationFrame = requestAnimationFrame(drawNetwork);
  }
}

function setActiveCard(card) {
  cards.forEach((item) => item.classList.toggle("is-active", item === card));
  activeCode.textContent = card.dataset.code;
  activeDetail.textContent = card.dataset.detail;
}

function initializeReveal() {
  const revealItems = document.querySelectorAll(".reveal");

  if (!("IntersectionObserver" in window)) {
    revealItems.forEach((item) => item.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.16 },
  );

  revealItems.forEach((item) => observer.observe(item));
}

cards.forEach((card) => {
  card.addEventListener("mouseenter", () => setActiveCard(card));
  card.addEventListener("focus", () => setActiveCard(card));
  card.addEventListener("click", () => setActiveCard(card));
});

window.addEventListener("pointermove", (event) => {
  pointer.x = event.clientX;
  pointer.y = event.clientY;
});

window.addEventListener("resize", resizeCanvas);

reducedMotion.addEventListener("change", () => {
  cancelAnimationFrame(animationFrame);
  resizeCanvas();
  drawNetwork();
});

resizeCanvas();
drawNetwork();
initializeReveal();
setActiveCard(cards[0]);
