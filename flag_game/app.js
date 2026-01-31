// Game State
let countriesData = [];
let currentRoundData = {};
let score = 0;
let timeLeft = 60;
let timerInterval;
const TOTAL_TIME = 60;
let currentDifficulty = 'easy'; // 'easy' or 'hard'
let worldMapSvgContent = ''; // Cache the SVG

// DOM Elements
const views = {
    menu: document.getElementById('menu-view'),
    game: document.getElementById('game-view'),
    gameOver: document.getElementById('game-over-view')
};

const dom = {
    easyBtn: document.getElementById('easy-btn'),
    hardBtn: document.getElementById('hard-btn'),
    questionContainer: document.getElementById('question-container'), // Replaces targetImg
    optionsContainer: document.getElementById('options-container'),
    scoreDisplay: document.getElementById('score-display'),
    timeDisplay: document.getElementById('time-display'),
    timerFill: document.getElementById('timer-fill'),
    finalScore: document.getElementById('final-score'),
    restartBtn: document.getElementById('restart-btn'),
    highScoreMsg: document.getElementById('high-score-msg')
};

// Initialize
async function init() {
    try {
        // Load data in parallel
        const [countriesRes, mapRes] = await Promise.all([
            fetch('https://restcountries.com/v3.1/all?fields=name,flags,cca2'),
            fetch('assets/world-map.svg')
        ]);

        const data = await countriesRes.json();
        worldMapSvgContent = await mapRes.text();

        // Extract IDs from SVG to ensure we only include countries valid on the map
        // Regex matches id="code" or id='code'
        const svgIds = new Set();
        const idRegex = /id=["']([a-zA-Z0-9_]+)["']/g;
        let match;
        while ((match = idRegex.exec(worldMapSvgContent)) !== null) {
            svgIds.add(match[1].toLowerCase());
        }

        console.log(`Found ${svgIds.size} valid regions in the map.`);

        // Filter valid countries
        countriesData = data.filter(c =>
            c.cca2 &&
            c.name && c.name.common &&
            c.flags && c.flags.png &&
            svgIds.has(c.cca2.toLowerCase())
        );

        console.log(`Loaded ${countriesData.length} countries (filtered by map availability). Map loaded.`);

        dom.easyBtn.onclick = () => startGame('easy');
        dom.hardBtn.onclick = () => startGame('hard');
        dom.restartBtn.onclick = () => switchView('menu'); // Go back to menu to text difficulty again

    } catch (err) {
        console.error("Failed to load game assets", err);
        alert("Failed to load game data or map. Check console.");
    }
}

function switchView(viewName) {
    Object.values(views).forEach(v => {
        v.classList.add('hidden');
        v.classList.remove('active-view');
    });
    views[viewName].classList.remove('hidden');
    setTimeout(() => {
        views[viewName].classList.add('active-view');
    }, 10);
}

function startGame(difficulty) {
    currentDifficulty = difficulty;
    score = 0;
    timeLeft = TOTAL_TIME;
    updateScore();
    updateTimer();
    switchView('game');
    startTimer();
    nextRound();
}

function startTimer() {
    clearInterval(timerInterval);
    timerInterval = setInterval(() => {
        timeLeft--;
        updateTimer();
        if (timeLeft <= 0) {
            endGame();
        }
    }, 1000);
}

function updateTimer() {
    dom.timeDisplay.textContent = timeLeft;
    const percentage = (timeLeft / TOTAL_TIME) * 100;
    dom.timerFill.style.width = `${percentage}%`;
    dom.timerFill.style.backgroundColor = timeLeft <= 10 ? '#ef4444' : '#3b82f6';
}

function updateScore() {
    dom.scoreDisplay.textContent = score;
}

function nextRound() {
    if (timeLeft <= 0) return;

    // Pick Answer
    const randomIndex = Math.floor(Math.random() * countriesData.length);
    const correctCountry = countriesData[randomIndex];

    // Pick Distractors
    const options = [correctCountry];
    while (options.length < 4) {
        const rand = Math.floor(Math.random() * countriesData.length);
        const distractor = countriesData[rand];
        if (!options.includes(distractor)) {
            options.push(distractor);
        }
    }
    options.sort(() => Math.random() - 0.5);

    currentRoundData = { correct: correctCountry, options: options };
    renderRound();
}

function renderRound() {
    const code = currentRoundData.correct.cca2.toLowerCase();

    // CLEAR container
    dom.questionContainer.innerHTML = '';

    if (currentDifficulty === 'hard') {
        // HARD MODE: Isolated IMG
        const img = document.createElement('img');
        img.className = 'outline-img';
        img.src = `https://raw.githubusercontent.com/djaiss/mapsicon/master/all/${code}/vector.svg`;
        img.alt = "Guess the country";

        // Handle image errors (some codes might not exist in mapsicon)
        img.onerror = () => {
            console.warn(`Outline not found for ${code}, skipping...`);
            nextRound();
        };

        dom.questionContainer.appendChild(img);
    } else {
        // EASY MODE: Full World Map with Highlight
        dom.questionContainer.innerHTML = worldMapSvgContent;

        // Highlight logic
        // The SVG uses lower case iso codes as ids usually, or sometimes specific names. 
        // We need to try to find the path by ID.
        // We'll try lowercase, uppercase, and generic search.

        setTimeout(() => {
            const svg = dom.questionContainer.querySelector('svg');
            if (svg) {
                // Remove any previous highlights
                svg.querySelectorAll('.target-country').forEach(p => p.classList.remove('target-country'));

                // Try to find the element
                let target = svg.getElementById(code); // try lowercase
                if (!target) target = svg.getElementById(code.toUpperCase());

                if (target) {
                    target.classList.add('target-country');
                    // If target is a group, ensure all child paths get the class for CSS styling
                    if (target.tagName === 'g' || target.tagName === 'G') {
                        target.querySelectorAll('path').forEach(p => p.classList.add('target-country'));
                    }

                    // --- SMART ZOOM LOGIC ---
                    try {
                        const bbox = target.getBBox();
                        if (bbox) {
                            // Calculate center
                            const cx = bbox.x + bbox.width / 2;
                            const cy = bbox.y + bbox.height / 2;

                            // Determine zoom level
                            // We want to show at least a certain area around the country for context.
                            // Let's define a minimum view dimension (e.g., 200 units).
                            // If the country is smaller than that, we zoom out to show 200 units.
                            // If it's larger, we show the country + padding.

                            const minViewSize = 300; // Minimum SVG units to show (controls max zoom-in)
                            const padding = 1.5; // 150% of the object size

                            let width = Math.max(bbox.width * padding, minViewSize);
                            let height = Math.max(bbox.height * padding, minViewSize);

                            // Maintain aspect ratio of the container (approx 1000x500 usually for world maps, 
                            // but our container is responsive. Let's assume a standard map ratio or just square-ish focus).
                            // Actually, best to just ensure we don't distort. SVG viewBox handles ratio if preserveAspectRatio is set (default).
                            // But to be safe, let's keep the viewbox somewhat rectangular if the map is.
                            // Let's just set the viewbox to the calculated area.

                            // Clamp to map boundaries (assuming standard 1000x500 approx map size, 
                            // but we should read actual viewBox if possible. For now, assuming standard world map coords).
                            // We won't clamp strictly to avoid complex logic reading raw SVG attribs, 
                            // just center on the object.

                            const x = cx - width / 2;
                            const y = cy - height / 2;

                            // Smooth transition (if supported, else instant)
                            svg.style.transition = 'all 1s ease-in-out'; // This might not animate viewBox in all browsers but worth a try

                            // Update ViewBox
                            svg.setAttribute('viewBox', `${x} ${y} ${width} ${height}`);
                        }
                    } catch (e) {
                        console.warn("Could not zoom to country", e);
                    }
                    // ------------------------

                } else {
                    console.warn(`Context map path not found for ${code}`);
                }
            }
        }, 10);
    }

    // Render Options
    dom.optionsContainer.innerHTML = '';
    currentRoundData.options.forEach(opt => {
        const btn = document.createElement('div');
        btn.className = 'option-card';

        const img = document.createElement('img');
        img.src = opt.flags.png;
        img.alt = opt.name.common;

        const span = document.createElement('span');
        span.textContent = opt.name.common;

        btn.appendChild(img);
        btn.appendChild(span);
        btn.onclick = () => handleAnswer(opt, btn);
        dom.optionsContainer.appendChild(btn);
    });
}

function handleAnswer(selected, btnElement) {
    const isCorrect = selected.name.common === currentRoundData.correct.name.common;
    const allBtns = document.querySelectorAll('.option-card');

    dom.optionsContainer.style.pointerEvents = 'none';

    if (isCorrect) {
        btnElement.classList.add('correct');
        score += 10;
        updateScore();
        // Bonus time logic optional
    } else {
        btnElement.classList.add('wrong');
        allBtns.forEach(b => {
            if (b.querySelector('span').textContent === currentRoundData.correct.name.common) {
                b.classList.add('correct');
            }
        });
        timeLeft = Math.max(0, timeLeft - 5);
        updateTimer();
    }

    if (timeLeft > 0) {
        setTimeout(() => {
            dom.optionsContainer.style.pointerEvents = 'all';
            nextRound();
        }, 1200);
    }
}

function endGame() {
    clearInterval(timerInterval);
    dom.finalScore.textContent = score;

    // Simple High Score Logic (could separate by Difficulty)
    const highScore = localStorage.getItem('flagMasterHighScore') || 0;
    if (score > highScore) {
        localStorage.setItem('flagMasterHighScore', score);
        dom.highScoreMsg.classList.remove('hidden');
    } else {
        dom.highScoreMsg.classList.add('hidden');
    }

    switchView('gameOver');
}

init();
