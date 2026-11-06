if (!window.Vue) {
    const app = document.querySelector('#app');
    if (app) app.style.display = 'none';
    console.error('[rsblood-progressbar] Vue failed to load — progress bar disabled.');
} else {
    const { createApp, ref, computed, onMounted, onBeforeUnmount } = Vue;

    createApp({
        setup() {
            const window_config = ref({
                label: 'Progress',
                icon: 'fa-solid fa-spinner',
                theme: 'default',
                position: 'center-bottom',
            });

            const stages = ref([]);
            const progress = ref(0);
            const current_stage_index = ref(0);
            const total_duration = ref(0);
            const can_cancel = ref(false);
            const remaining_time = ref(0);
            const is_active = ref(false);
            const locale = ref({});

            const current_stage = computed(() => (
                stages.value[current_stage_index.value] || stages.value[0] || {}
            ));
            const current_stage_message = computed(() => (
                current_stage.value.message || window_config.value.label || 'Working...'
            ));
            const progress_percent = computed(() => Math.min(
                100,
                Math.max(0, Math.round(Number(progress.value) || 0)),
            ));
            const progress_color = computed(() => (
                current_stage.value.progressColor || '#d9252b'
            ));
            const padded_stage_number = computed(() => String(
                Math.min(current_stage_index.value + 1, Math.max(stages.value.length, 1)),
            ).padStart(2, '0'));
            const padded_stage_total = computed(() => String(
                Math.max(stages.value.length, 1),
            ).padStart(2, '0'));

            let interval_id = null;
            let remaining_interval_id = null;
            let finish_timeout_id = null;
            let stage_start_time = null;
            let active_session_id = null;
            let is_finishing = false;

            function post(name, payload) {
                try {
                    return fetch(`https://${GetParentResourceName()}/${name}`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                        body: JSON.stringify(payload || {}),
                    }).catch(() => undefined);
                } catch (_) {
                    return Promise.resolve();
                }
            }

            function clear_timers() {
                if (interval_id) clearInterval(interval_id);
                if (remaining_interval_id) clearInterval(remaining_interval_id);
                if (finish_timeout_id) clearTimeout(finish_timeout_id);
                interval_id = null;
                remaining_interval_id = null;
                finish_timeout_id = null;
                stage_start_time = null;
            }

            function reset_runtime() {
                clear_timers();
                is_finishing = false;
                is_active.value = false;
                progress.value = 0;
                current_stage_index.value = 0;
                total_duration.value = 0;
                remaining_time.value = 0;
                stages.value = [];
            }

            function update_remaining_time() {
                let elapsed = 0;
                for (let i = 0; i < current_stage_index.value; i++) {
                    elapsed += Number(stages.value[i]?.duration || 0);
                }
                if (stage_start_time) elapsed += Date.now() - stage_start_time;
                const remaining = Math.max(total_duration.value - elapsed, 0) / 1000;
                remaining_time.value = remaining.toFixed(1);
            }

            function stage_percent_start(index) {
                if (!total_duration.value) return 0;
                const sum_before = stages.value
                    .slice(0, index)
                    .reduce((sum, stage) => sum + Number(stage.duration || 0), 0);
                return (sum_before / total_duration.value) * 100;
            }

            function stage_percent_end(index) {
                if (!total_duration.value) return 100;
                const sum_to = stages.value
                    .slice(0, index + 1)
                    .reduce((sum, stage) => sum + Number(stage.duration || 0), 0);
                return (sum_to / total_duration.value) * 100;
            }

            function finish(cancelled) {
                if (is_finishing || active_session_id === null) return;
                is_finishing = true;

                const finished_session_id = active_session_id;
                clear_timers();

                finish_timeout_id = setTimeout(() => {
                    if (active_session_id !== finished_session_id) return;

                    is_active.value = false;
                    post('progressFinished', {
                        sessionId: finished_session_id,
                        cancelled: cancelled === true,
                    });

                    active_session_id = null;
                    reset_runtime();
                }, 250);
            }

            function run_stage() {
                if (is_finishing || active_session_id === null) return;

                if (current_stage_index.value >= stages.value.length) {
                    finish(false);
                    return;
                }

                const stage = stages.value[current_stage_index.value];
                if (!stage) {
                    finish(true);
                    return;
                }

                if (stage.condition) return;

                if (stage.minigame) {
                    post('stageMinigame', {
                        sessionId: active_session_id,
                        stage_index: current_stage_index.value,
                        timestamp: Date.now(),
                    });
                }

                stage_start_time = Date.now();
                const start_percent = stage_percent_start(current_stage_index.value);
                const end_percent = stage_percent_end(current_stage_index.value);

                post('stageStart', {
                    sessionId: active_session_id,
                    stage_index: current_stage_index.value,
                    timestamp: Date.now(),
                });

                if (interval_id) clearInterval(interval_id);
                interval_id = setInterval(() => {
                    const elapsed = Date.now() - stage_start_time;
                    const duration = Math.max(Number(stage.duration || 1), 1);
                    const ratio = Math.min(elapsed / duration, 1);
                    progress.value = start_percent + (end_percent - start_percent) * ratio;

                    if (ratio < 1) return;

                    clearInterval(interval_id);
                    interval_id = null;
                    stage.finished = true;

                    post('stageFinished', {
                        sessionId: active_session_id,
                        stage_index: current_stage_index.value,
                        timestamp: Date.now(),
                    });

                    if (current_stage_index.value < stages.value.length - 1) {
                        current_stage_index.value += 1;
                        run_stage();
                    } else {
                        progress.value = 100;
                        remaining_time.value = 0;
                        finish(false);
                    }
                }, 80);
            }

            function start_progress() {
                is_active.value = true;
                is_finishing = false;
                progress.value = 0;
                current_stage_index.value = 0;
                remaining_interval_id = setInterval(update_remaining_time, 50);
                update_remaining_time();
                run_stage();
            }

            function skip_current_stage() {
                if (is_finishing || active_session_id === null) return;
                if (interval_id) clearInterval(interval_id);
                interval_id = null;
                stage_start_time = null;

                const index = current_stage_index.value;
                const stage = stages.value[index];
                if (!stage) {
                    finish(true);
                    return;
                }

                stage.finished = true;
                progress.value = stage_percent_end(index);
                update_remaining_time();

                post('stageFinished', {
                    sessionId: active_session_id,
                    stage_index: index,
                    skipped: true,
                    timestamp: Date.now(),
                });

                if (index < stages.value.length - 1) {
                    current_stage_index.value += 1;
                    setTimeout(run_stage, 10);
                } else {
                    remaining_time.value = 0;
                    progress.value = 100;
                    finish(false);
                }
            }

            function handle_message(event) {
                const payload = event.data || {};
                const action = payload.action;
                const data = payload.data || {};

                if (action === 'START_PROGRESS') {
                    reset_runtime();
                    active_session_id = Number(data.sessionId);
                    if (!Number.isFinite(active_session_id)) return;

                    window_config.value.label = data.label || 'Progress';
                    window_config.value.icon = data.icon || 'fa-solid fa-spinner';
                    window_config.value.theme = data.theme || 'default';
                    window_config.value.position = data.position || 'center-bottom';
                    window_config.value.iconColor = data.iconColor || '#ff4b5c';
                    can_cancel.value = Boolean(data.canCancel);

                    stages.value = Array.isArray(data.stages) && data.stages.length > 0
                        ? data.stages.map((stage) => ({ ...stage, duration: Math.max(Number(stage.duration || 1), 1) }))
                        : [{
                            message: data.label || 'Working...',
                            duration: Math.max(Number(data.duration || 3000), 1),
                            progressColor: data.progressColor,
                        }];

                    total_duration.value = stages.value.reduce(
                        (sum, stage) => sum + Number(stage.duration || 0),
                        0,
                    );
                    start_progress();
                    return;
                }

                if (action === 'SET_LOCALE') {
                    locale.value = data.locale || {};
                    return;
                }

                if (Number(data.sessionId) !== active_session_id) return;

                if (action === 'CANCEL') {
                    finish(true);
                } else if (action === 'CONDITIONAL_SKIP') {
                    if (Number(data.index) !== current_stage_index.value) return;
                    skip_current_stage();
                } else if (action === 'MINIGAME_RESULT') {
                    if (data.result === true && current_stage_index.value === Number(data.stage_index) - 1) {
                        skip_current_stage();
                    } else {
                        const stage = stages.value[current_stage_index.value];
                        post('minigameFailed', {
                            sessionId: active_session_id,
                            stage_index: current_stage_index.value,
                            data,
                            timestamp: Date.now(),
                        });

                        if (stage?.cancelMode === 'hard') finish(true);
                    }
                }
            }

            onMounted(() => {
                window.addEventListener('message', handle_message);
                post('ready', { timestamp: Date.now() });
            });

            onBeforeUnmount(() => {
                clear_timers();
                window.removeEventListener('message', handle_message);
            });

            return {
                locale,
                window_config,
                stages,
                progress,
                current_stage_index,
                remaining_time,
                can_cancel,
                is_active,
                current_stage_message,
                progress_percent,
                progress_color,
                padded_stage_number,
                padded_stage_total,
            };
        },
    }).mount('#app');
}
