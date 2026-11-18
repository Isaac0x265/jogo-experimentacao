extends RefCounted
## CONTEUDO DO JOGO: as fases e os textos educativos.
## Quer mudar um texto, uma dica ou quais obstaculos aparecem numa fase? E aqui.
## Este arquivo so tem dados (nenhuma logica). Quem usa e o jogo/main.gd:
##   const DADOS := preload("res://jogo/fases.gd")   ->   DADOS.FASES, DADOS.INFO...

## Cada fase = um lugar do Brasil com seus problemas ambientais.
## Listas com itens repetidos funcionam como "peso" no sorteio.
const FASES := [
	{
		"nome": "RUA DO NORDESTE",
		"cenario": preload("res://cenarios/scenery_rua.tscn"),
		"cima": ["fio"],
		"baixo": ["lixo", "lixo", "vidro"],
		"aereos": ["garrafa", "papel"],
	},
	{
		"nome": "FORTALEZA",
		"cenario": preload("res://cenarios/scenery_fortaleza.tscn"),
		"cima": ["rede"],
		"baixo": ["esgoto", "esgoto", "entulho"],
		"aereos": ["sacola", "sacola", "pet"],
	},
	{
		"nome": "RIO DE JANEIRO",
		"cenario": preload("res://cenarios/scenery_rio.tscn"),
		"cima": ["balao"],
		"baixo": ["baia", "deslizamento"],
		"aereos": ["balaozinho", "balaozinho", "pet"],
		"aereo_y": [30.0, 220.0],      # baloes nascem no alto e vao descendo
	},
]

## Explicacao mostrada quando o gato bate em cada obstaculo:
## [titulo, o que aconteceu, por que importa, como ajudar, icone]
## Obs.: a fonte Press Start 2P desenha mal MAIUSCULAS acentuadas -> titulos sem acento.
## (Dados das fases 2+ no relatorio "Problemas ambientais das fases".)
const IMPORTA_PLASTICO := "Plástico se quebra em microplástico, que tartarugas e peixes confundem com comida."
const AJUDA_PLASTICO := "Leve seu lixo de volta da praia e recicle no ecoponto."
const IMPORTA_BALAO := "Balão pode cair ainda aceso e começar incêndios em matas e casas."
const AJUDA_BALAO := "Soltar balão é crime. Viu um? Denuncie à Linha Verde."
const INFO := {
	"fio": ["FIO SOLTO!",
		"O gato encostou num fio de poste caído.",
		"Fio solto pode estar com energia e dar choque em pessoas e animais.",
		"Não encoste! Avise a companhia de energia.", "fio"],
	"lixo": ["LIXO NA RUA!",
		"O gato trombou numa lixeira transbordando.",
		"Lixo fora do lugar entope bueiros e causa alagamentos.",
		"Feche bem o saco e só coloque na rua no dia da coleta.", "lixo"],
	"vidro": ["CACOS DE VIDRO!",
		"O gato passou por cima de vidro quebrado.",
		"Cacos soltos cortam pessoas, animais e os garis.",
		"Embrulhe vidro quebrado em jornal antes de jogar fora.", "vidro"],
	"garrafa": ["GARRAFA JOGADA!",
		"Alguém arremessou uma garrafa na rua.",
		"Garrafa jogada vira caco, e vidro é 100% reciclável.",
		"Leve ao ponto de coleta (lixeira verde).", "garrafa"],
	"papel": ["PAPEL NA RUA!",
		"Um papel voando acertou o gato.",
		"Papel jogado na rua vai parar no bueiro.",
		"Recicle na lixeira azul.", "papel"],
	"esgoto": ["ESGOTO NO MAR!",
		"O gato bateu numa galeria despejando esgoto na praia.",
		"Esgoto não é chuva! Ele deixa a água imprópria e causa doenças.",
		"Ligue sua casa à rede da CAGECE e veja o boletim da SEMACE antes do banho.", "esgoto"],
	"entulho": ["ENTULHO NO MANGUE!",
		"Tinha entulho jogado em cima das raízes do mangue.",
		"Mangue é berçário do mar: muitos peixes e caranguejos nascem ali.",
		"Não jogue entulho no Cocó. Chame o Limpezinha pelo 156.", "entulho"],
	"rede": ["PLASTICO NO MAR!",
		"O gato se enroscou numa rede de pesca abandonada.",
		IMPORTA_PLASTICO, AJUDA_PLASTICO, "plastico"],
	"sacola": ["PLASTICO NO MAR!",
		"Uma sacola plástica flutuando acertou o gato.",
		IMPORTA_PLASTICO, AJUDA_PLASTICO, "plastico"],
	"pet": ["PLASTICO NO MAR!",
		"Uma garrafa PET voou na direção do gato.",
		IMPORTA_PLASTICO, AJUDA_PLASTICO, "plastico"],
	"baia": ["LIXO NA BAIA!",
		"O gato bateu no lixo preso na ecobarreira.",
		"Lixo jogado na rua desce pelos rios e vai parar na Baía de Guanabara.",
		"Jogue no lixo e separe o reciclável.", "baia"],
	"deslizamento": ["DESLIZAMENTO!",
		"Lama e pedras desceram o morro.",
		"A árvore segura o morro. Lixo na encosta deixa o terreno instável.",
		"Não jogue lixo na encosta e, se a sirene tocar, saia já.", "deslizamento"],
	"balao": ["BALAO!",
		"Um balão aceso cruzou o caminho do gato.",
		IMPORTA_BALAO, AJUDA_BALAO, "balao"],
	"balaozinho": ["BALAO!",
		"Um balão aceso caiu em cima do gato.",
		IMPORTA_BALAO, AJUDA_BALAO, "balao"],
}
## Quando o gato so cai no chao: uma dica verde e uma dica de jogo sorteadas.
const DICAS_VERDES := [
	"Separe o lixo seco do úmido: isso ajuda a reciclagem.",
	"Leve sua garrafinha e evite copo descartável.",
	"Não jogue óleo de cozinha na pia: guarde numa garrafa e leve a um ponto de coleta.",
	"Pilhas e baterias não vão no lixo comum: procure um ponto de coleta.",
]
const DICAS_JOGO := [
	"Passe pelo meio do buraco: PERFEITO vale pontos em dobro.",
	"3 PERFEITOS seguidos sobem o multiplicador, até x4!",
	"Pegue as folhas no caminho: valem pontos extras.",
	"Voe até a bolha com a resposta certa: vale pontos e conta para a fase!",
]
