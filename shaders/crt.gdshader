shader_type canvas_item;
// Filtro de tela (F3 liga e desliga): brilho do neon (bloom), linhas de
// varredura, leve aberração cromática nas bordas, vinheta e grão.
// Fica numa camada acima de tudo e lê a imagem já desenhada da tela.

uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float brilho : hint_range(0.0, 2.0) = 0.55;
uniform float limiar : hint_range(0.0, 1.0) = 0.42;
uniform float linhas : hint_range(0.0, 1.0) = 0.1;
uniform float aberracao : hint_range(0.0, 4.0) = 1.2;
uniform float vinheta : hint_range(0.0, 1.5) = 0.55;
uniform float grao : hint_range(0.0, 0.2) = 0.035;

vec3 claro(vec2 uv) {
	vec3 c = texture(tela, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(limiar, 1.0, l);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 centro = uv - 0.5;
	float d2 = dot(centro, centro);

	// aberração cromática: cresce do centro para as bordas
	vec2 desloc = centro * d2 * aberracao * 0.02 + vec2(px.x * aberracao * 0.35, 0.0);
	vec3 cor;
	cor.r = texture(tela, uv + desloc).r;
	cor.g = texture(tela, uv).g;
	cor.b = texture(tela, uv - desloc).b;

	// bloom barato: soma das partes claras em volta (dois anéis)
	vec3 soma = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 dir = vec2(cos(a), sin(a));
		soma += claro(uv + dir * px * 3.0) * 0.6;
		soma += claro(uv + dir * px * 7.0) * 0.4;
	}
	cor += soma / 8.0 * brilho;

	// linhas de varredura (uma a cada linha de pixel do jogo)
	float linha = 0.5 + 0.5 * sin((uv.y / px.y) * 3.14159265);
	cor *= 1.0 - linhas * (1.0 - linha);

	// vinheta
	cor *= 1.0 - vinheta * d2 * 1.6;

	// grão
	float ruido = fract(sin(dot(uv * (TIME + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	cor += (ruido - 0.5) * grao;

	COLOR = vec4(cor, 1.0);
}
