# FlapyBirdIntegrado — arquivo de backup

Esta branch `backup` preserva o projeto encontrado em 16/11/2026, incluindo
as duas pastas de cópias antigas e o ZIP original do primeiro commit.
Para desenvolver, use a branch `atual` (`git switch atual`).

## O que foi preservado

| Caminho | Conteúdo |
| --- | --- |
| `flapy-bird-integrado.zip` | Pacote original, recuperado sem alterações do commit `64d3415`. Inclui código, recursos, backups e cache da época. |
| `flapy-bird-integrado/project.godot` | Configuração do projeto atual, com entrada em `scenes/menu.tscn`. |
| `flapy-bird-integrado/scripts/` | Lógica atual do jogo, menu, personagem, obstáculos, cenários e skins. |
| `flapy-bird-integrado/scenes/` | Cenas atuais e cenário procedural anterior mantido como recurso. |
| `flapy-bird-integrado/assets/` | Imagens, fonte e licença usadas pelo projeto. |
| `flapy-bird-integrado/_backup_antes_rua_nordeste/` | Cópia parcial anterior à inclusão da Rua do Nordeste e dos obstáculos, datada de 14/11/2026 no `LEIA.txt`. |
| `flapy-bird-integrado/_backup_antes_grafico_v2/` | Cópia parcial anterior à melhoria gráfica, datada de 14/11/2026 no `LEIA.txt`. |

As pastas `_backup_*` não são projetos completos nem versões independentes
executáveis. Elas preservam apenas alguns scripts e cenas. Os arquivos `.gd`
correspondem a `scripts/` e os `.tscn` a `scenes/`; compare as diferenças antes
de restaurá-los. Os dois conjuntos representam momentos distintos e não devem
ser sobrepostos indiscriminadamente.

Na comparação do ZIP com a pasta local, os 356 arquivos presentes em ambos
eram idênticos byte a byte. Os 55 arquivos do ZIP ausentes localmente eram
somente caches de shaders em `.godot/`.

## Arquivos auxiliares

- `.godot/`: cache e estado local do editor; ignorados pelo Git fora do ZIP.
- `*.import`: configurações de importação dos recursos; mantidas no Git.
- `*.gd.uid`: identificadores dos scripts; mantidos no Git.
- `.editorconfig`, `.gitattributes`, `.gitignore`: configuração do projeto e do Git.

## Branches

- `backup`: fotografia de preservação, com o ZIP e as cópias históricas.
- `atual`: projeto para desenvolvimento, sem o ZIP e sem as pastas `_backup_*`.
- `main`: permanece no commit original, que continha somente o ZIP.

Salve suas alterações em um commit antes de trocar de branch. Use
`git switch backup` para consultar este arquivo e `git switch atual` para
retomar o desenvolvimento. Novas versões devem ser registradas com commits,
evitando novas pastas de backup dentro do projeto.
