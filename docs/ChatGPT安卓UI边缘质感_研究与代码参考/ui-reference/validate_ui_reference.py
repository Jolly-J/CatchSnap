"""Text guardrails only. Not a Kotlin compiler, screenshot test, or GPU benchmark."""
from pathlib import Path
root = Path(__file__).parent
code = (root / 'LightweightGlossSurface.kt').read_text()
checks = {
    'shape cached': 'remember(cornerRadius)' in code,
    'brush cached': 'remember(edgeTopColor, edgeBottomColor)' in code,
    'shadow cached': 'remember(softShadowRadius, softShadowColor, softShadowOffset)' in code,
    'shared theme policy': 'Color(0x26FFFFFF)' in code and '0.5.dp else 0.dp' in code,
    'solid edge supported': 'SolidColor(edgeTopColor)' in code,
    'shadow outside content clip': code.index('.then(shadowModifier)') < code.index('.clip(shape)'),
    'radius not confused with elevation': 'Modifier.dropShadow(shape = shape, shadow = softShadow)' in code,
    'composer values': all(s in code for s in ['cornerRadius = 24.dp','alpha = 0.97f','softShadowRadius = 50.dp','alpha = 0.15f']),
    'no content/backdrop blur calls': '.blur(' not in code and 'RenderEffect' not in code,
    'gradient marked as experiment': 'design experiment' in code,
}
output = 'Static text checks only; Kotlin compilation, render QA, and device performance: NOT RUN.\n'
output += '\n'.join(f'{"PASS" if ok else "FAIL"}: {name}' for name,ok in checks.items()) + '\n'
(root / 'validation.txt').write_text(output)
print(output)
assert all(checks.values())
