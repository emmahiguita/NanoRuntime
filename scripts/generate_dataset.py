import asyncio
import json
import os
from openai import AsyncOpenAI

# Script para generar 10k ejemplos de alucinaciones sintéticas en código
# Require configurar OPENAI_API_KEY en variables de entorno

async def generate_examples(client: AsyncOpenAI, batch_size: int = 10):
    prompt = """
    Genera un ejemplo de código en Python o Rust que contenga una alucinación (ej. usar una función que no existe en una librería popular).
    Debes devolver la respuesta estrictamente en JSON con este esquema:
    {
      "code": "<código con alucinación>",
      "language": "python|rust",
      "has_hallucination": true,
      "hallucination_type": "<tipo de alucinación>",
      "correct_version": "<código corregido>"
    }
    No agregues markdown, solo el JSON raw.
    """
    
    tasks = []
    for _ in range(batch_size):
        tasks.append(
            client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7
            )
        )
    
    results = await asyncio.gather(*tasks)
    
    valid_examples = []
    for res in results:
        content = res.choices[0].message.content.strip()
        if content.startswith("```json"):
            content = content[7:-3]
        try:
            data = json.loads(content)
            valid_examples.append(data)
        except Exception as e:
            print(f"Failed to parse JSON: {e}")
            
    return valid_examples

async def main():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("Set OPENAI_API_KEY environment variable")
        return

    client = AsyncOpenAI(api_key=api_key)
    target_count = 10000
    current_count = 0
    output_file = "../data/hallucinations_10k.jsonl"
    
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, "a") as f:
        while current_count < target_count:
            print(f"Generating... ({current_count}/{target_count})")
            examples = await generate_examples(client, batch_size=20)
            for ex in examples:
                f.write(json.dumps(ex) + "\n")
                current_count += 1
                if current_count >= target_count:
                    break

    print("Generation complete!")

if __name__ == "__main__":
    asyncio.run(main())
