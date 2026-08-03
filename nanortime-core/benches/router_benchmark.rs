use criterion::{black_box, criterion_group, criterion_main, Criterion};
use nanortime_core::config::manifest::Config;
use nanortime_core::execution::ModelManager;

fn bench_routing(c: &mut Criterion) {
    let rt = tokio::runtime::Runtime::new().unwrap();

    c.bench_function("route_simple_query", |b| {
        let config = Config::test_config();
        let model_manager = rt.block_on(async { ModelManager::new(config.clone()).await.unwrap() });

        b.iter(|| {
            rt.block_on(async {
                let (_text, _scores) = model_manager
                    .generate_with_confidence(black_box("¿Qué hora es?"), 100)
                    .await
                    .unwrap();
            })
        });
    });

    c.bench_function("route_complex_query", |b| {
        let config = Config::test_config();
        let model_manager = rt.block_on(async { ModelManager::new(config.clone()).await.unwrap() });

        b.iter(|| {
            rt.block_on(async {
                let (_text, _scores) = model_manager
                    .generate_with_confidence(
                        black_box("Explain the theory of general relativity in detail"),
                        100,
                    )
                    .await
                    .unwrap();
            })
        });
    });
}

fn bench_entropy(c: &mut Criterion) {
    use nanortime_core::orchestrator::confidence::calculate_entropy;

    let small_dist = vec![0.9, 0.05, 0.03, 0.02];
    let large_dist: Vec<f32> = (0..1000).map(|i| 1.0 / (i + 1) as f32).collect();

    c.bench_function("entropy_small", |b| {
        b.iter(|| calculate_entropy(black_box(&small_dist)));
    });

    c.bench_function("entropy_large", |b| {
        b.iter(|| calculate_entropy(black_box(&large_dist)));
    });
}

fn bench_privacy(c: &mut Criterion) {
    use nanortime_core::orchestrator::privacy;

    let clean_text = "Hello, how are you today? I hope you're doing well.";
    let pii_text = "My email is juan@ejemplo.com and my card is 4111-1111-1111-1111. Call me at 555-123-4567.";

    c.bench_function("privacy_clean", |b| {
        b.iter(|| privacy::contains_pii(black_box(clean_text)));
    });

    c.bench_function("privacy_pii", |b| {
        b.iter(|| privacy::contains_pii(black_box(pii_text)));
    });

    c.bench_function("privacy_anonymize", |b| {
        b.iter(|| privacy::anonymize(black_box(pii_text)));
    });
}

criterion_group!(benches, bench_routing, bench_entropy, bench_privacy);
criterion_main!(benches);
