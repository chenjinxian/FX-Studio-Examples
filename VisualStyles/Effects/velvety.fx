/************* Resources *************/

cbuffer CBufferPerObject
{
	float4x4 WorldITXf : WorldInverseTranspose	< string UIWidget = "None"; >;
	float4x4 WvpXf     : WorldViewProjection	< string UIWidget = "None"; >;
	float4x4 WorldXf   : World					< string UIWidget = "None"; >;
	float4x4 ViewIXf   : ViewInverse			< string UIWidget = "None"; >;

	float3 Lamp0Pos : Position <
		string Object = "PointLight0";
		string UIName = "Lamp 0 Position";
		string Space = "World";
	> = { -0.5f, 2.0f, 1.25f };

	float3 Lamp0Color : Specular <
		string UIName = "Lamp 0 Color";
		string Object = "Pointlight0";
		string UIWidget = "Color";
	> = { 1.0f, 1.0f, 1.0f };
}

cbuffer CBufferPerFrame
{
	float3 SurfaceColor : DIFFUSE <
		string UIName = "Surface";
		string UIWidget = "Color";
	> = { 0.5f, 0.5f, 0.5f };

	float3 FuzzySpecColor <
		string UIWidget = "Color";
		string UIName = "Fuzz";
	> = { 0.7f, 0.7f, 0.75f };

	float3 SubColor <
		string UIWidget = "Color";
		string UIName = "Under-Color";
	> = { 0.2f, 0.2f, 1.0f };

	float RollOff <
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 1.0;
		float UIStep = 0.05;
		string UIName = "Edge Rolloff";
	> = 0.3;
}

Texture2D ColorTexture : DIFFUSE <
	string ResourceName = "DefaultColor.dds";
	string UIName = "Diffuse Texture";
	string ResourceType = "2D";
>;

SamplerState ColorSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

/************* Data Structures *************/

struct VS_INPUT
{
	float3 Position	: POSITION;
	float2 UV		: TEXCOORD0;
	float3 Normal	: NORMAL;
	float3 Tangent	: TANGENT;
	float3 Binormal : BINORMAL;
};

struct VS_OUTPUT
{
	float4 HPosition		: SV_Position;
	float3 WorldNormal		: NORMAL;
	float3 WorldTangent		: TANGENT;
	float3 WorldBinormal	: BINORMAL;
	float2 UV				: TEXCOORD0;
	float3 LightVec			: TEXCOORD1;
	float3 WorldView		: TEXCOORD2;
};

struct velvetVS_OUTPUT
{
	float4 HPosition		: SV_Position;
	float2 UV				: TEXCOORD0;
	float4 DColor			: COLOR0;
	float4 SColor			: COLOR1;
};

/************* Vertex Shader *************/

VS_OUTPUT vertex_shader(VS_INPUT IN)
{
	VS_OUTPUT OUT = (VS_OUTPUT)0;

	float4 Po = float4(IN.Position.xyz, 1.0);
	OUT.HPosition = mul(Po, WvpXf);

	OUT.WorldNormal = normalize(mul(float4(IN.Normal, 0), WorldITXf).xyz);
	OUT.WorldTangent = normalize(mul(float4(IN.Tangent, 0), WorldITXf).xyz);
	OUT.WorldBinormal = normalize(mul(float4(IN.Binormal, 0), WorldITXf).xyz);

	float3 Pw = mul(Po, WorldXf).xyz;
	OUT.LightVec = normalize(Lamp0Pos - Pw);
#ifdef FLIP_TEXTURE_Y
	OUT.UV = float2(IN.UV.x, (1.0 - IN.UV.y));
#else
	OUT.UV = IN.UV;
#endif
	OUT.WorldView = normalize(ViewIXf[3].xyz - Pw);

	return OUT;
}

velvetVS_OUTPUT velvet_vertex_shader(VS_INPUT IN)
{
	velvetVS_OUTPUT OUT = (velvetVS_OUTPUT)0;

	float4 Po = float4(IN.Position.xyz, 1.0);
	OUT.HPosition = mul(Po, WvpXf);
	OUT.UV = IN.UV;

	float3 Pw = mul(Po, WorldXf).xyz;
	float3 Nn = normalize(mul(float4(IN.Normal, 0), WorldITXf).xyz);
	float3 Ln = normalize(Lamp0Pos - Pw);
	float ldn = dot(Ln, Nn);
	float diffComp = max(0, ldn);
	float3 diffContrib = diffComp * SurfaceColor;

	float subLamb = smoothstep(-RollOff, 1.0, ldn) - smoothstep(0.0, 1.0, ldn);
	subLamb = max(0.0, subLamb);
	float3 subContrib = subLamb * SubColor;

	float3 Vn = normalize(ViewIXf[3].xyz - Pw);
	float vdn = 1.0 - dot(Vn, Nn);
	float3 vecColor = vdn.xxx;
	OUT.DColor = float4((subContrib + diffContrib).xyz, 1);
	OUT.SColor = float4((vecColor * FuzzySpecColor).xyz, 1);

	return OUT;
}

/************* Pixel Shader *************/

void velvet_shared(VS_OUTPUT IN,
	out float3 DiffuseContrib,
	out float3 SpecularContrib)
{
	float ldn = dot(IN.LightVec, IN.WorldNormal);
	float diffComp = max(0, ldn);
	float vdn = 1.0 - dot(IN.WorldView, IN.WorldNormal);
	float3 diffContrib = diffComp * SurfaceColor;
	float subLamb = smoothstep(-RollOff, 1.0, ldn) - smoothstep(0.0, 1.0, ldn);
	subLamb = max(0.0, subLamb);
	float3 subContrib = subLamb * SubColor;
	float3 vecColor = vdn.xxx;
	DiffuseContrib = (subContrib + diffContrib).xyz;
	SpecularContrib = (vecColor * FuzzySpecColor).xyz;
}

float4 velvet_pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float3 diffContrib;
	float3 specContrib;
	velvet_shared(IN, diffContrib, specContrib);
	float3 litC = diffContrib + specContrib;
	return float4(litC.rgb, 1);
}

float4 velvet_pixel_shader_t(VS_OUTPUT IN) : SV_Target
{
	float3 diffContrib;
	float3 specContrib;
	velvet_shared(IN, diffContrib, specContrib);
	float3 litC = diffContrib + specContrib;
	float4 T = ColorTexture.Sample(ColorSampler, IN.UV);
	return float4(litC.rgb * T.rgb, T.a);
}

float4 pixel_shader(velvetVS_OUTPUT IN) : SV_Target
{
	float4 result = IN.DColor + IN.SColor;
	return float4(result.xyz, 1);
}

float4 pixel_shader_t(velvetVS_OUTPUT IN) : SV_Target
{
	float4 map = ColorTexture.Sample(ColorSampler, IN.UV);
	float4 result = IN.SColor + (IN.DColor * map);
	return float4(result.xyz, 1);
}

RasterizerState DisableCulling
{
	CullMode = NONE;
};

/************* Techniques *************/

technique11 Textured
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, velvet_pixel_shader()));

		SetRasterizerState(DisableCulling);
	}
}

technique11 Simple
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, velvet_pixel_shader()));

		SetRasterizerState(DisableCulling);
	}
}

technique11 VertexTextured
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, velvet_vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, pixel_shader_t()));

		SetRasterizerState(DisableCulling);
	}
}

technique11 VertexSimple
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, velvet_vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, pixel_shader()));

		SetRasterizerState(DisableCulling);
	}
}
