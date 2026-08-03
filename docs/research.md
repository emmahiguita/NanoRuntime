# NanoAI Research

## Real-Time Hallucination Detection and Correction for Code Generation in Edge LLMs

### Objective

Develop a lightweight classifier (50-100M parameters) that runs in parallel with the main LLM during code generation, detecting hallucinations in real-time and triggering corrective prompts before the user sees erroneous code.

### Contributions

1. **Dataset**: 10k labeled code examples with hallucinations in Python, JavaScript, and Rust
2. **Classifier**: Lightweight model (BERT-base, 110M params) fine-tuned for hallucination detection
3. **Correction System**: Mechanism to interrupt generation and correct hallucinations proactively
4. **Metrics**: New evaluation metrics for streaming hallucination detection
5. **Integration**: Demo with NanoAI showing edge LLMs matching large model reliability

### Timeline

| Month | Activity | Deliverable |
|-------|----------|-------------|
| 1-2 | Literature review | Survey document |
| 2-3 | Dataset creation (1k) | Initial dataset |
| 3-4 | Dataset expansion (10k) | Full dataset |
| 4-5 | Classifier training | Trained model |
| 5-6 | Classifier evaluation | Evaluation metrics |
| 6-7 | NanoAI integration | Integrated system |
| 7-8 | A/B testing | Test results |
| 8-9 | Classifier refinement | Improved model |
| 9-10 | Paper writing | Initial draft |
| 10-11 | Review and editing | Final paper |
| 11-12 | Conference submission | Submitted paper |

### Target Conferences

1. **ACL 2026** — Deadline: Jan 2026
2. **EMNLP 2026** — Deadline: Jun 2026  
3. **ICSE 2026** — Deadline: Aug 2026

### Resources

- GPU: RTX 3060/4060 (available)
- RAM: 32GB (available)
- Cloud: Google Colab (free tier)
- APIs: ~$100 budget for GPT-4/Claude

### Dataset Format

```json
{
  "code": "import numpy as np\n\ndef foo():\n    return np.non_existent_func()",
  "language": "python",
  "has_hallucination": true,
  "hallucination_type": "non_existent_api",
  "correct_version": "import numpy as np\n\ndef foo():\n    return np.array([1, 2, 3])",
  "source": "gpt4_generated",
  "annotator_agreement": 0.95
}
```
