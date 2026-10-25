package example.gloss

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp

/**
 * Original adjustable design reconstruction, not extracted ChatGPT source.
 * One fill, one edge, one shadow; NO backdrop sampling or content blur.
 * Set edgeTopColor == edgeBottomColor for a solid edge (the observed candidates).
 * A different bottom color is an OPTIONAL design experiment, not APK evidence.
 */
@Composable
fun LightweightGlossSurface(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    fillColor: Color = Color.White.copy(alpha = 0.70f),
    edgeWidth: Dp = 1.dp,
    edgeTopColor: Color = Color.White.copy(alpha = 0.55f),
    edgeBottomColor: Color = edgeTopColor,
    elevation: Dp = 6.dp,
    // Non-null selects a radius-based drop shadow instead of elevation shadow.
    softShadowRadius: Dp? = null,
    softShadowColor: Color = Color.Black.copy(alpha = 0.15f),
    softShadowOffset: DpOffset = DpOffset.Zero,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable BoxScope.() -> Unit,
) {
    require(cornerRadius >= 0.dp && edgeWidth >= 0.dp && elevation >= 0.dp)
    require(softShadowRadius == null || softShadowRadius >= 0.dp)
    val shape = remember(cornerRadius) { RoundedCornerShape(cornerRadius) }
    // Cache brushes across recompositions; no per-frame allocation in a draw lambda.
    val edgeBrush = remember(edgeTopColor, edgeBottomColor) {
        if (edgeTopColor == edgeBottomColor) SolidColor(edgeTopColor)
        else Brush.verticalGradient(listOf(edgeTopColor, edgeBottomColor))
    }
    val softShadow = remember(softShadowRadius, softShadowColor, softShadowOffset) {
        softShadowRadius?.let { radius ->
            Shadow(radius = radius, color = softShadowColor, spread = 0.dp, offset = softShadowOffset)
        }
    }
    val shadowModifier = if (softShadow != null) {
        Modifier.dropShadow(shape = shape, shadow = softShadow)
    } else {
        Modifier.shadow(elevation = elevation, shape = shape, clip = false)
    }
    val edgeModifier = if (edgeWidth > 0.dp) Modifier.border(edgeWidth, edgeBrush, shape) else Modifier
    Box(
        modifier.then(shadowModifier)
            .background(fillColor, shape)
            .then(edgeModifier)
            .clip(shape)
            .padding(contentPadding),
        content = content,
    )
}

/**
 * SharedSurface theme policy study: dark thin edge, light shadow without default edge.
 * Radius, supplied fill, and light elevation are DESIGN choices, not decoded shared tokens.
 */
@Composable
fun SharedSurfaceReference(
    darkTheme: Boolean,
    surfaceColor: Color,
    modifier: Modifier = Modifier,
    forceBorderInLight: Boolean = false,
    designCornerRadius: Dp = 24.dp,
    designLightElevation: Dp = 6.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    LightweightGlossSurface(
        modifier = modifier,
        cornerRadius = designCornerRadius,
        fillColor = surfaceColor,
        edgeWidth = if (darkTheme || forceBorderInLight) 0.5.dp else 0.dp,
        edgeTopColor = if (darkTheme) Color(0x26FFFFFF) else Color(0x1A000000),
        elevation = if (darkTheme) 0.dp else designLightElevation,
        content = content,
    )
}

/** Rounded composer skin only: this is NOT a complete text-input implementation. */
@Composable
fun ComposerSurfaceReference(
    darkTheme: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    val base = if (darkTheme) Color(0xFF303030) else Color.White
    LightweightGlossSurface(
        modifier = modifier,
        cornerRadius = 24.dp,
        fillColor = base.copy(alpha = 0.97f),
        edgeWidth = 1.dp,
        edgeTopColor = base, // solid original base color, not a white gradient highlight
        softShadowRadius = 50.dp,
        softShadowColor = Color.Black.copy(alpha = 0.15f),
        softShadowOffset = DpOffset.Zero, // design choice; do not misread fallback elevation as offset
        content = content,
    )
}

/** Pro artwork candidate: solid outer edge + INTERNAL gradient, not gradient stroke. */
@Composable
fun ProArtworkCapsuleReference(modifier: Modifier = Modifier) {
    val insideBrush = remember {
        Brush.horizontalGradient(listOf(Color(0xFF9639ED), Color(0xFFA25BFF)))
    }
    LightweightGlossSurface(
        modifier = modifier.width(248.dp).height(56.dp),
        cornerRadius = 999.dp, // clamped radius gives a capsule; APK uses 50 percent corners
        fillColor = Color.White.copy(alpha = 0.70f),
        edgeTopColor = Color.White.copy(alpha = 0.55f),
        elevation = 12.dp,
        contentPadding = PaddingValues(8.dp),
    ) {
        Box(
            Modifier.fillMaxSize().background(insideBrush, RoundedCornerShape(percent = 50)),
            contentAlignment = Alignment.Center,
        ) { BasicText("Design reference", style = TextStyle(color = Color.White)) }
    }
}

/** Fixed light-theme card token was confirmed opaque white; tint stays adjustable. */
@Composable
fun ProConnectorCardReference(cardSurfaceColor: Color = Color.White, modifier: Modifier = Modifier) {
    LightweightGlossSurface(
        modifier = modifier.size(80.dp),
        cornerRadius = 20.dp,
        fillColor = cardSurfaceColor,
        edgeTopColor = Color.White.copy(alpha = 0.55f),
        elevation = 6.dp,
        contentPadding = PaddingValues(8.dp),
    ) { BasicText("Card", style = TextStyle(color = Color.Black)) }
}

/** Look at the same surface against different backgrounds before tuning its alpha. */
@Composable
fun GlossSurfaceStudyDemo() {
    val backgrounds = remember { listOf(Color(0xFFF2F2F2), Color(0xFFD9E4F5), Color(0xFF151515)) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        backgrounds.forEachIndexed { index, background ->
            val textColor = if (index == 2) Color.White else Color.Black
            Column(
                Modifier.fillMaxWidth().background(background).padding(28.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                BasicText("Background ${index + 1}", style = TextStyle(color = textColor))
                SharedSurfaceReference(
                    darkTheme = index == 2,
                    surfaceColor = if (index == 2) Color(0xFF303030) else Color.White,
                    modifier = Modifier.fillMaxWidth(),
                ) { BasicText("Shared surface policy", style = TextStyle(color = textColor)) }
                ProArtworkCapsuleReference()
                // Confirmed fixed-light token is opaque white, not the capsule's white at 70%.
                ProConnectorCardReference(cardSurfaceColor = Color.White)
                LightweightGlossSurface(
                    modifier = Modifier.fillMaxWidth(),
                    edgeBottomColor = Color.White.copy(alpha = 0.10f),
                ) { BasicText("Optional gradient edge — design experiment") }
                ComposerSurfaceReference(darkTheme = index == 2, modifier = Modifier.fillMaxWidth()) {
                    BasicText("Composer skin (not an input)", style = TextStyle(color = textColor))
                }
            }
        }
    }
}
