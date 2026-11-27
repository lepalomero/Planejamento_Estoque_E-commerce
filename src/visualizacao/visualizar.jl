using Dates

# Execute: julia src\visualizacao\visualizar.jl [diretorio_picking]
isdefined(@__MODULE__, :ConfigEstoque) ||
    include(joinpath(@__DIR__, "..", "config", "config.jl"))
isdefined(@__MODULE__, :ItemArmazenado) ||
    include(joinpath(@__DIR__, "..", "modelo", "estoque.jl"))
isdefined(@__MODULE__, :Warehouse) ||
    include(joinpath(@__DIR__, "..", "modelo", "warehouse.jl"))
isdefined(@__MODULE__, :caminho_estantes) ||
    include(joinpath(@__DIR__, "..", "estoque", "distancia.jl"))

const _CAMINHOES_VISUALIZADOS = (
    (id=1, cor="#dc2626", traco="8 5"),
    (id=2, cor="#2563eb", traco="3 4"),
    (id=3, cor="#16a34a", traco="none"),
)

const _CORES_METODOS = (
    "abc_sku" => "#7c3aed",
    "random" => "#ea580c",
    "coocorrencia" => "#0f766e",
)

function _campos_csv(linha::AbstractString)
    campos = String[]
    buffer = IOBuffer()
    caracteres = collect(linha)
    entre_aspas = false
    indice = 1

    while indice <= length(caracteres)
        caractere = caracteres[indice]
        if caractere == '"'
            if entre_aspas && indice < length(caracteres) &&
               caracteres[indice + 1] == '"'
                write(buffer, '"')
                indice += 1
            else
                entre_aspas = !entre_aspas
            end
        elseif caractere == ',' && !entre_aspas
            push!(campos, String(take!(buffer)))
        else
            write(buffer, caractere)
        end
        indice += 1
    end

    entre_aspas && throw(ArgumentError("Linha CSV com aspas nao fechadas"))
    push!(campos, String(take!(buffer)))
    return campos
end

function _ler_csv(caminho)
    isfile(caminho) || throw(ArgumentError("Arquivo CSV nao encontrado: $(caminho)"))
    linhas = readlines(caminho)
    isempty(linhas) && throw(ArgumentError("Arquivo CSV vazio: $(caminho)"))

    cabecalho = _campos_csv(first(linhas))
    dados = Vector{Vector{String}}()
    for (indice, linha) in enumerate(linhas[2:end])
        isempty(linha) && continue
        campos = _campos_csv(linha)
        numero_linha = indice + 1
        length(campos) >= length(cabecalho) || throw(ArgumentError(
            "Linha $(numero_linha) incompleta em $(caminho)",
        ))
        push!(dados, campos)
    end
    return cabecalho, dados
end

function _indice_coluna(cabecalho, nome, caminho)
    indice = findfirst(==(nome), cabecalho)
    indice === nothing && throw(ArgumentError(
        "Coluna $(nome) nao encontrada em $(caminho)",
    ))
    return indice
end

function _ler_grafo(caminho)
    cabecalho, linhas = _ler_csv(caminho)
    origem_col = _indice_coluna(cabecalho, "origem", caminho)
    destino_col = _indice_coluna(cabecalho, "destino", caminho)
    distancia_col = _indice_coluna(cabecalho, "distancia", caminho)
    estoque_col = _indice_coluna(cabecalho, "estoque_origem", caminho)

    arestas = Tuple{Int,Int,Float64}[]
    itens_por_no = Dict{Int,Int}()
    maior_no = 1
    for linha in linhas
        origem = parse(Int, linha[origem_col])
        destino = parse(Int, linha[destino_col])
        distancia = parse(Float64, linha[distancia_col])
        maior_no = max(maior_no, origem, destino)
        push!(arestas, (origem, destino, distancia))

        estoque = linha[estoque_col]
        itens_por_no[origem] = isempty(estoque) ? 0 :
            count(!isempty, split(estoque, ';'))
    end
    return arestas, itens_por_no, maior_no
end

function _ler_rota(caminho, caminhao_id; permitir_vazia=false)
    cabecalho, linhas = _ler_csv(caminho)
    caminhao_col = _indice_coluna(cabecalho, "caminhao_id", caminho)
    ordem_col = _indice_coluna(cabecalho, "ordem", caminho)
    estante_col = _indice_coluna(cabecalho, "estante_id", caminho)
    x_col = _indice_coluna(cabecalho, "posicao_x", caminho)
    y_col = _indice_coluna(cabecalho, "posicao_y", caminho)

    rota = NamedTuple[]
    for linha in linhas
        parse(Int, linha[caminhao_col]) == caminhao_id || continue
        push!(
            rota,
            (
                ordem=parse(Int, linha[ordem_col]),
                estante_id=parse(Int, linha[estante_col]),
                x=parse(Float64, linha[x_col]),
                y=parse(Float64, linha[y_col]),
            ),
        )
    end
    sort!(rota; by=parada -> parada.ordem)
    isempty(rota) && !permitir_vazia && throw(ArgumentError(
        "Nenhuma rota do caminhao $(caminhao_id) encontrada em $(caminho)",
    ))
    return rota
end

function _validar_posicoes_rota(rota, warehouse, caminho)
    for parada in rota
        indice_estante = parada.estante_id + 1
        1 <= indice_estante <= length(warehouse.estantes) || throw(ArgumentError(
            "Estante $(parada.estante_id) fora do grafo em $(caminho)",
        ))
        x, y = warehouse.estantes[indice_estante].posicao
        isapprox(parada.x, x; atol=1e-8) && isapprox(parada.y, y; atol=1e-8) ||
            throw(ArgumentError(
                "Coordenadas desatualizadas em $(caminho). Gere novamente os CSVs com julia --project=. src\\main.jl",
            ))
    end
    return rota
end

function _escapar_xml(texto)
    saida = string(texto)
    for (caractere, entidade) in (
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&apos;",
    )
        saida = replace(saida, caractere => entidade)
    end
    return saida
end

function _posicao_svg(x, y, margem_esquerda, margem_superior, escala, x_min, y_max)
    return (
        margem_esquerda + (x - x_min) * escala,
        margem_superior + (y_max - y) * escala,
    )
end

function _pontos_svg(caminho, margem_esquerda, margem_superior, escala, x_min, y_max)
    return join(
        (
            begin
                x, y = _posicao_svg(
                    ponto[1],
                    ponto[2],
                    margem_esquerda,
                    margem_superior,
                    escala,
                    x_min,
                    y_max,
                )
                "$(x),$(y)"
            end for ponto in caminho
        ),
        ' ',
    )
end

function _desenhar_grafo(caminho_saida, caminho_grafo, titulo; rotas=NamedTuple[])
    arestas, itens_por_no, maior_no = _ler_grafo(caminho_grafo)
    quantidade_estantes = maior_no - 1
    config = ConfigEstoque(n_estantes=max(1, quantidade_estantes))
    warehouse = Warehouse(config)
    for rota in rotas
        _validar_posicoes_rota(rota.paradas, warehouse, caminho_grafo)
    end

    metade_comprimento = config.comprimento_armazem / 2
    x_min = -metade_comprimento
    x_max = metade_comprimento
    y_max = config.largura_armazem - 1
    escala = 13
    margem_esquerda = 70
    margem_superior = 88
    margem_direita = 70
    margem_inferior = 122
    largura_svg = margem_esquerda + margem_direita + (x_max - x_min) * escala
    altura_svg = margem_superior + margem_inferior + (y_max + 1) * escala

    open(caminho_saida, "w") do svg
        println(svg, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $(largura_svg) $(altura_svg)" role="img">""")
        println(svg, """<rect width="100%" height="100%" fill="#ffffff"/>""")
        println(svg, """<text x="$(margem_esquerda)" y="34" font-family="Arial,sans-serif" font-size="24" font-weight="bold" fill="#172554">$(_escapar_xml(titulo))</text>""")
        if !isempty(rotas)
            descricao_rotas = join(
                ("Caminhao $(rota.caminhao_id): $(length(rota.paradas)) paradas" for rota in rotas),
                " | ",
            )
            println(svg, """<text x="$(margem_esquerda)" y="59" font-family="Arial,sans-serif" font-size="14" fill="#475569">$(_escapar_xml(descricao_rotas)); caminhos calculados pelos corredores</text>""")
        else
            println(svg, """<text x="$(margem_esquerda)" y="59" font-family="Arial,sans-serif" font-size="14" fill="#475569">$(quantidade_estantes) estantes - conexoes desenhadas pelas distancias permitidas</text>""")
        end

        println(svg, """<g fill="none" stroke="#64748b" stroke-opacity="0.14" stroke-width="0.8">""")
        for (origem, destino, _) in arestas
            origem < destino || continue
            caminho = caminho_estantes(
                warehouse.estantes[origem],
                warehouse.estantes[destino],
                config.largura_armazem,
                config.comprimento_armazem,
            )
            pontos = _pontos_svg(
                caminho,
                margem_esquerda,
                margem_superior,
                escala,
                x_min,
                y_max,
            )
            println(svg, """<polyline points="$(pontos)"><title>Aresta $(origem)-$(destino)</title></polyline>""")
        end
        println(svg, "</g>")

        println(svg, """<g fill="none" stroke="#334155" stroke-width="3" stroke-linecap="round">""")
        for x_corredor in (-metade_comprimento, 0.0, metade_comprimento)
            x1, y1 = _posicao_svg(
                x_corredor,
                0,
                margem_esquerda,
                margem_superior,
                escala,
                x_min,
                y_max,
            )
            x2, y2 = _posicao_svg(
                x_corredor,
                y_max,
                margem_esquerda,
                margem_superior,
                escala,
                x_min,
                y_max,
            )
            println(svg, """<line x1="$(x1)" y1="$(y1)" x2="$(x2)" y2="$(y2)"/>""")
        end
        println(svg, "</g>")

        for rota in rotas
            length(rota.paradas) >= 2 || continue
            println(svg, """<g fill="none" stroke="$(rota.cor)" stroke-opacity="0.8" stroke-width="3.5" stroke-dasharray="$(rota.traco)" stroke-linecap="round" stroke-linejoin="round">""")
            for indice in 1:(length(rota.paradas) - 1)
                atual = warehouse.estantes[rota.paradas[indice].estante_id + 1]
                proxima = warehouse.estantes[rota.paradas[indice + 1].estante_id + 1]
                caminho = caminho_estantes(
                    atual,
                    proxima,
                    config.largura_armazem,
                    config.comprimento_armazem,
                )
                pontos = _pontos_svg(
                    caminho,
                    margem_esquerda,
                    margem_superior,
                    escala,
                    x_min,
                    y_max,
                )
                println(svg, """<polyline points="$(pontos)"/>""")
            end
            println(svg, "</g>")
        end

        for no in 1:maior_no
            estante = warehouse.estantes[no]
            x, y = _posicao_svg(
                estante.posicao[1],
                estante.posicao[2],
                margem_esquerda,
                margem_superior,
                escala,
                x_min,
                y_max,
            )
            if estante.eh_saida
                cor = "#0f172a"
                raio = 5
                descricao = "Saida do armazem (0,0)"
            else
                quantidade_itens = get(itens_por_no, no, 0)
                cor = quantidade_itens > 0 ? "#2563eb" : "#cbd5e1"
                raio = 3.2
                descricao = "Estante $(estante.id) - $(quantidade_itens) SKUs"
            end
            println(svg, """<circle cx="$(x)" cy="$(y)" r="$(raio)" fill="$(cor)" stroke="#ffffff" stroke-width="0.7"><title>$(_escapar_xml(descricao))</title></circle>""")
        end

        for (indice_rota, rota) in enumerate(rotas)
            for parada in rota.paradas
                estante = warehouse.estantes[parada.estante_id + 1]
                x, y = _posicao_svg(
                    estante.posicao[1],
                    estante.posicao[2],
                    margem_esquerda,
                    margem_superior,
                    escala,
                    x_min,
                    y_max,
                )
                deslocamento_x = (indice_rota - 2) * 7
                deslocamento_y = -7 - (indice_rota - 1) * 3
                println(svg, """<circle cx="$(x + deslocamento_x)" cy="$(y + deslocamento_y)" r="7" fill="$(rota.cor)" stroke="#ffffff" stroke-width="1.5"/>""")
                println(svg, """<text x="$(x + deslocamento_x)" y="$(y + deslocamento_y + 2.5)" text-anchor="middle" font-family="Arial,sans-serif" font-size="8" font-weight="bold" fill="#ffffff">$(parada.ordem)</text>""")
            end
        end

        y_legenda = altura_svg - 54
        println(svg, """<g font-family="Arial,sans-serif" font-size="12" fill="#334155">""")
        println(svg, """<circle cx="$(margem_esquerda + 5)" cy="$(y_legenda - 4)" r="5" fill="#0f172a"/><text x="$(margem_esquerda + 16)" y="$(y_legenda)">Saida</text>""")
        println(svg, """<circle cx="$(margem_esquerda + 95)" cy="$(y_legenda - 4)" r="5" fill="#2563eb"/><text x="$(margem_esquerda + 106)" y="$(y_legenda)">Estante com estoque</text>""")
        println(svg, """<circle cx="$(margem_esquerda + 270)" cy="$(y_legenda - 4)" r="5" fill="#cbd5e1"/><text x="$(margem_esquerda + 281)" y="$(y_legenda)">Estante sem estoque</text>""")
        println(svg, """<line x1="$(margem_esquerda + 430)" y1="$(y_legenda - 4)" x2="$(margem_esquerda + 460)" y2="$(y_legenda - 4)" stroke="#334155" stroke-width="3"/><text x="$(margem_esquerda + 468)" y="$(y_legenda)">Corredores</text>""")
        for (indice_rota, rota) in enumerate(rotas)
            x_legenda = margem_esquerda + (indice_rota - 1) * 170
            y_rota = y_legenda + 20
            println(svg, """<line x1="$(x_legenda)" y1="$(y_rota - 4)" x2="$(x_legenda + 28)" y2="$(y_rota - 4)" stroke="$(rota.cor)" stroke-width="3.5" stroke-dasharray="$(rota.traco)"/><text x="$(x_legenda + 36)" y="$(y_rota)">Caminhao $(rota.caminhao_id)</text>""")
        end
        println(svg, """<text x="$(margem_esquerda)" y="$(altura_svg - 8)" font-size="11" fill="#64748b">Cada trecho segue a menor rota entre o corredor central e os corredores laterais.</text>""")
        println(svg, "</g>")
        println(svg, "</svg>")
    end
    return caminho_saida
end

function _gerar_indice(caminho_saida, visuais)
    metodo = basename(dirname(dirname(caminho_saida)))
    open(caminho_saida, "w") do html
        titulo = _escapar_xml("Visualizacoes do picking - $(metodo)")
        println(html, """<!doctype html><html lang="pt-br"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$(titulo)</title>""")
        println(html, """<style>body{font-family:Arial,sans-serif;margin:24px;background:#f8fafc;color:#172554}h1{margin-bottom:8px}.nota{color:#475569;margin-bottom:24px}.galeria{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:20px}.cartao{background:white;border:1px solid #cbd5e1;border-radius:8px;padding:12px}.cartao img{width:100%;height:auto}.cartao a{color:#1d4ed8;font-weight:bold;text-decoration:none}</style></head><body><h1>$(titulo)</h1>""")
        println(html, """<p class="nota">Mapas de rota para todas as waves. Caminhoes 1, 2 e 3 aparecem em vermelho, azul e verde; os graficos temporais mostram todas as waves e somam as distancias de todos os caminhoes. O grafico comparativo distingue abc_sku, random e coocorrencia por cor.</p><main class="galeria">""")
        for visual in visuais
            nome = basename(visual)
            println(html, """<article class="cartao"><a href="$(_escapar_xml(nome))"><img src="$(_escapar_xml(nome))" alt="$(_escapar_xml(splitext(nome)[1]))"><br>$(_escapar_xml(splitext(nome)[1]))</a></article>""")
        end
        println(html, "</main></body></html>")
    end
    return caminho_saida
end

function _sufixar_arquivo_visual(nome, sufixo_metodo)
    isempty(sufixo_metodo) && return nome
    base, extensao = splitext(nome)
    return "$(base)_$(sufixo_metodo)$(extensao)"
end

function _data_wave(nome, prefixo, sufixo_metodo)
    final = isempty(sufixo_metodo) ? ".csv" : "_$(sufixo_metodo).csv"
    startswith(nome, prefixo) && endswith(nome, final) ||
        throw(ArgumentError("Nome de arquivo de wave invalido: $(nome)"))
    texto_data = replace(replace(nome, prefixo => ""; count=1), final => "")
    return Date(texto_data, dateformat"yyyy-mm-dd")
end

function _distancias_por_data(pasta_picking, sufixo_metodo)
    sufixo = isempty(sufixo_metodo) ? ".csv" : "_$(sufixo_metodo).csv"
    arquivos = sort(filter(
        nome -> startswith(nome, "distancia_wave_") && endswith(nome, sufixo),
        readdir(pasta_picking),
    ))
    distancias = Dict{Date,Float64}()
    for nome in arquivos
        data_wave = _data_wave(nome, "distancia_wave_", sufixo_metodo)
        caminho = joinpath(pasta_picking, nome)
        cabecalho, linhas = _ler_csv(caminho)
        semana_col = _indice_coluna(cabecalho, "semana", caminho)
        distancia_col = _indice_coluna(cabecalho, "distancia_percorrida", caminho)
        total = 0.0
        for linha in linhas
            data_linha = Date(linha[semana_col], dateformat"yyyy-mm-dd")
            data_linha == data_wave || throw(ArgumentError(
                "Data da wave inconsistente em $(caminho)",
            ))
            distancia = parse(Float64, linha[distancia_col])
            isfinite(distancia) && distancia >= 0 ||
                throw(ArgumentError("Distancia invalida em $(caminho)"))
            total += distancia
        end
        isempty(linhas) && throw(ArgumentError("CSV de distancia sem dados: $(caminho)"))
        distancias[data_wave] = total
    end
    return distancias
end

function _desenhar_grafico_temporal(caminho_saida, titulo, series)
    datas = sort!(unique(vcat((collect(keys(serie.valores)) for serie in series)...)))
    isempty(datas) && throw(ArgumentError("Nao ha datas para o grafico temporal"))
    valores = [
        valor
        for serie in series
        for valor in values(serie.valores)
    ]
    isempty(valores) && throw(ArgumentError("Nao ha distancias para o grafico temporal"))
    all(valor -> isfinite(valor) && valor >= 0, valores) ||
        throw(ArgumentError("O grafico temporal recebeu distancias invalidas"))

    largura, altura = 960, 500
    margem_esquerda, margem_direita = 90, 35
    topo, base = 100, 405
    eixo_x = largura - margem_direita
    maximo_y = maximum(valores)
    maximo_y = maximo_y == 0 ? 1.0 : maximo_y * 1.08
    duracao_dias = Dates.value(last(datas) - first(datas))
    posicao_x(data) = duracao_dias == 0 ? (margem_esquerda + eixo_x) / 2 :
        margem_esquerda + Dates.value(data - first(datas)) *
        (eixo_x - margem_esquerda) / duracao_dias
    posicao_y(valor) = base - valor * (base - topo) / maximo_y

    mkpath(dirname(caminho_saida))
    open(caminho_saida, "w") do svg
        println(svg, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $(largura) $(altura)" role="img">""")
        println(svg, """<rect width="100%" height="100%" fill="#ffffff"/>""")
        println(svg, """<text x="$(margem_esquerda)" y="34" font-family="Arial,sans-serif" font-size="24" font-weight="bold" fill="#172554">$(_escapar_xml(titulo))</text>""")
        for (indice, serie) in enumerate(series)
            x = margem_esquerda + (indice - 1) * 220
            println(svg, """<line x1="$(x)" y1="66" x2="$(x + 28)" y2="66" stroke="$(serie.cor)" stroke-width="3.5"/>""")
            println(svg, """<text x="$(x + 36)" y="70" font-family="Arial,sans-serif" font-size="13" fill="#334155">$(_escapar_xml(serie.nome))</text>""")
        end

        for indice_tick in 0:5
            valor_tick = maximo_y * indice_tick / 5
            y = posicao_y(valor_tick)
            println(svg, """<line x1="$(margem_esquerda)" y1="$(y)" x2="$(eixo_x)" y2="$(y)" stroke="#cbd5e1" stroke-width="1"/>""")
            println(svg, """<text x="$(margem_esquerda - 10)" y="$(y + 4)" text-anchor="end" font-family="Arial,sans-serif" font-size="11" fill="#475569">$(round(valor_tick; digits=1))</text>""")
        end
        println(svg, """<line x1="$(margem_esquerda)" y1="$(topo)" x2="$(margem_esquerda)" y2="$(base)" stroke="#334155" stroke-width="1.5"/>""")
        println(svg, """<line x1="$(margem_esquerda)" y1="$(base)" x2="$(eixo_x)" y2="$(base)" stroke="#334155" stroke-width="1.5"/>""")

        for serie in series
            pontos = [
                "$(posicao_x(data)),$(posicao_y(serie.valores[data]))"
                for data in datas
                if haskey(serie.valores, data)
            ]
            if length(pontos) > 1
                println(svg, """<polyline points="$(join(pontos, ' '))" fill="none" stroke="$(serie.cor)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>""")
            end
            for data in datas
                haskey(serie.valores, data) || continue
                x, y = posicao_x(data), posicao_y(serie.valores[data])
                println(svg, """<circle cx="$(x)" cy="$(y)" r="4.5" fill="$(serie.cor)"><title>$(_escapar_xml(serie.nome)): $(Dates.format(data, dateformat"yyyy-mm-dd")) - $(serie.valores[data])</title></circle>""")
            end
        end
        for data in datas
            x = posicao_x(data)
            println(svg, """<text x="$(x)" y="$(base + 22)" text-anchor="middle" font-family="Arial,sans-serif" font-size="11" fill="#475569">$(Dates.format(data, dateformat"yyyy-mm-dd"))</text>""")
        end
        println(svg, """<text x="$(margem_esquerda)" y="$(altura - 12)" font-family="Arial,sans-serif" font-size="12" fill="#475569">Data de cada wave; distancia total somada entre todos os caminhoes.</text>""")
        println(svg, "</svg>")
    end
    return caminho_saida
end

function gerar_grafico_temporal_comparativo(pasta_picking)
    metodos = ("abc_sku", "random", "coocorrencia")
    distancias = Dict(
        metodo => _distancias_por_data(joinpath(pasta_picking, metodo), metodo)
        for metodo in metodos
    )
    all(metodo -> !isempty(distancias[metodo]), metodos) ||
        throw(ArgumentError("Faltam dados de distancia para um ou mais metodos"))
    series = [
        (
            nome=metodo == "abc_sku" ? "ABC SKU" :
                metodo == "random" ? "Aleatorio" : "Coocorrencia",
            cor=only(filter(par -> first(par) == metodo, _CORES_METODOS)).second,
            valores=distancias[metodo],
        ) for metodo in metodos
    ]
    return _desenhar_grafico_temporal(
        joinpath(
            pasta_picking,
            "distancia_temporal_abc_sku_random_coocorrencia.svg",
        ),
        "Distancia diaria por metodo",
        series,
    )
end

function gerar_visualizacoes(pasta_picking; sufixo_metodo="")
    isdir(pasta_picking) || throw(ArgumentError(
        "Diretorio de picking nao encontrado: $(pasta_picking)",
    ))
    if isempty(sufixo_metodo)
        pasta_metodo = basename(normpath(pasta_picking))
        pasta_metodo in ("abc_sku", "random", "coocorrencia") &&
            (sufixo_metodo = pasta_metodo)
    end
    pasta_visualizacoes = joinpath(pasta_picking, "visualizacoes")
    mkpath(pasta_visualizacoes)
    for nome in readdir(pasta_visualizacoes)
        ((startswith(nome, "index") && endswith(nome, ".html")) ||
         (startswith(nome, "grafo_") && endswith(nome, ".svg")) ||
         (startswith(nome, "distancia_temporal_") && endswith(nome, ".svg"))) &&
            rm(joinpath(pasta_visualizacoes, nome))
    end

    visuais = String[]
    caminho_inicial = joinpath(
        pasta_picking,
        _sufixar_arquivo_visual("grafo_inicial.csv", sufixo_metodo),
    )
    saida_inicial = joinpath(
        pasta_visualizacoes,
        _sufixar_arquivo_visual("grafo_inicial.svg", sufixo_metodo),
    )
    rotulo_metodo = isempty(sufixo_metodo) ? "" : " - $(sufixo_metodo)"
    push!(
        visuais,
        _desenhar_grafo(
            saida_inicial,
            caminho_inicial,
            "Grafo inicial do armazem$(rotulo_metodo)",
        ),
    )

    sufixo_csv = isempty(sufixo_metodo) ? ".csv" : "_$(sufixo_metodo).csv"
    grafos_wave = sort(filter(
        nome -> startswith(nome, "grafo_wave_") && endswith(nome, sufixo_csv),
        readdir(pasta_picking),
    ))
    grafo_por_data = Dict(
        _data_wave(nome, "grafo_wave_", sufixo_metodo) => nome
        for nome in grafos_wave
    )
    datas_waves = sort!(collect(keys(grafo_por_data)))
    for data_wave in datas_waves
        semana = Dates.format(data_wave, dateformat"yyyy-mm-dd")
        rotas = NamedTuple[]
        caminho_rota = joinpath(
            pasta_picking,
            _sufixar_arquivo_visual("rota_wave_$(semana).csv", sufixo_metodo),
        )
        for caminhao in _CAMINHOES_VISUALIZADOS
            push!(
                rotas,
                (
                    caminhao_id=caminhao.id,
                    paradas=_ler_rota(caminho_rota, caminhao.id; permitir_vazia=true),
                    cor=caminhao.cor,
                    traco=caminhao.traco,
                ),
            )
        end
        saida = joinpath(
            pasta_visualizacoes,
            _sufixar_arquivo_visual(
                "grafo_wave_$(semana)_caminhoes_1_2_3.svg",
                sufixo_metodo,
            ),
        )
        push!(
            visuais,
            _desenhar_grafo(
                saida,
                joinpath(pasta_picking, grafo_por_data[data_wave]),
                "Rotas dos caminhoes 1, 2 e 3 - wave $(semana)$(rotulo_metodo)";
                rotas=rotas,
            ),
        )
    end
    if !isempty(datas_waves)
        distancias = _distancias_por_data(pasta_picking, sufixo_metodo)
        all(data -> haskey(distancias, data), datas_waves) ||
            throw(ArgumentError("Faltam CSVs de distancia para algumas waves"))
        caminho_distancia = joinpath(
            pasta_visualizacoes,
            _sufixar_arquivo_visual("distancia_temporal.svg", sufixo_metodo),
        )
        push!(
            visuais,
            _desenhar_grafico_temporal(
                caminho_distancia,
                "Distancia total por wave$(rotulo_metodo)",
                [(nome=sufixo_metodo, cor="#334155", valores=distancias)],
            ),
        )
    end

    caminho_indice = _gerar_indice(
        joinpath(
            pasta_visualizacoes,
            _sufixar_arquivo_visual("index.html", sufixo_metodo),
        ),
        visuais,
    )
    println("Visualizacoes geradas em: $(caminho_indice)")
    println("Grafo inicial, $(length(datas_waves)) waves e rotas dos caminhoes 1, 2 e 3.")
    return caminho_indice
end

function main_visualizar(args=ARGS)
    length(args) <= 1 ||
        throw(ArgumentError("Informe somente o diretorio de picking"))
    pasta_padrao = normpath(joinpath(@__DIR__, "..", "..", "outputs", "picking", "abc_sku"))
    pasta_picking = isempty(args) ? pasta_padrao : abspath(args[1])
    pasta_metodo = basename(pasta_picking)
    sufixo_metodo =
        pasta_metodo in ("abc_sku", "random", "coocorrencia") ? pasta_metodo : ""
    return gerar_visualizacoes(
        pasta_picking;
        sufixo_metodo=sufixo_metodo,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_visualizar()
end
