import openai
import json
from pathlib import Path
from tqdm import tqdm

client = openai.OpenAI()

def evaluate_responses(input_file: str, output_file: str):
    data = json.loads(Path(input_file).read_text())
    results = []
    for item in tqdm(data):
        response = client.chat.completions.create(
            model='gpt-4o',
            messages=[{'role': 'user', 'content': item['prompt']}]
        )
        results.append({'prompt': item['prompt'], 'response': response.choices[0].message.content})
    Path(output_file).write_text(json.dumps(results, indent=2, ensure_ascii=False))

if __name__ == '__main__':
    import sys
    evaluate_responses(sys.argv[1], sys.argv[2])
