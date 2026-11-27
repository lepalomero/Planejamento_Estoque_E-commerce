const DIRETORIO_PROJETO = dirname(@__DIR__)
const DIRETORIO_PICKING = joinpath(DIRETORIO_PROJETO, "outputs", "picking")

function _distancia_arquivo(caminho)
    linhas = readlines(caminho)
    isempty(linhas) && throw(ArgumentError("CSV de distancia vazio: $(caminho)"))
    cabecalho = split(first(linhas), ',')
    indice_distancia = findfirst(==("distancia_percorrida"), cabecalho)
    indice_distancia === nothing && throw(ArgumentError(
        "Coluna distancia_percorrida ausente em $(caminho)",
    ))

    total = 0.0
    for (indice_linha, linha) in enumerate(linhas[2:end])
        isempty(strip(linha)) && continue
        campos = split(linha, ',')
        length(campos) >= indice_distancia || throw(ArgumentError(
            "Linha $(indice_linha + 1) incompleta em $(caminho)",
        ))
        distancia = parse(Float64, replace(strip(campos[indice_distancia]), "\"" => ""))
        isfinite(distancia) && distancia >= 0 || throw(ArgumentError(
            "Distancia invalida na linha $(indice_linha + 1) de $(caminho)",
        ))
        total += distancia
    end
    return total
end

function _arquivos_distancia(pasta_picking, heuristica)
    sufixo = "_$(heuristica).csv"
    return sort(filter(
        nome -> startswith(nome, "distancia_wave_") && endswith(nome, sufixo),
        readdir(pasta_picking),
    ))
end

function _distancia_total(pasta_picking, heuristica)
    pasta_heuristica = joinpath(pasta_picking, heuristica)
    isdir(pasta_heuristica) || throw(ArgumentError(
        "Pasta da heuristica $(heuristica) nao encontrada: $(pasta_heuristica). Execute src\\main.jl primeiro.",
    ))
    caminho_grafo = joinpath(
        pasta_heuristica,
        "grafo_inicial_$(heuristica).csv",
    )
    isfile(caminho_grafo) || throw(ArgumentError(
        "Resultado inicial de $(heuristica) nao encontrado: $(caminho_grafo). Execute src\\main.jl primeiro.",
    ))

    arquivos = _arquivos_distancia(pasta_heuristica, heuristica)
    isempty(arquivos) && throw(ArgumentError(
        "Nenhum CSV de distancia de $(heuristica) encontrado em $(pasta_heuristica).",
    ))

    return sum(
        _distancia_arquivo(joinpath(pasta_heuristica, nome))
        for nome in arquivos;
        init=0.0,
    )
end

function _tempo_execucao(pasta_picking, heuristica)
    caminho = joinpath(
        pasta_picking,
        heuristica,
        "tempo_execucao_$(heuristica).csv",
    )
    isfile(caminho) || throw(ArgumentError(
        "Tempo de execucao de $(heuristica) nao encontrado: $(caminho). Execute src\\main.jl primeiro.",
    ))
    linhas = readlines(caminho)
    length(linhas) == 2 ||
        throw(ArgumentError("CSV de tempo de execucao invalido: $(caminho)"))
    split(first(linhas), ',') == ["metodo", "tempo_execucao_segundos"] ||
        throw(ArgumentError("Cabecalho de tempo de execucao invalido: $(caminho)"))
    campos = split(linhas[2], ',')
    length(campos) == 2 && campos[1] == heuristica ||
        throw(ArgumentError("Linha de tempo de execucao invalida: $(caminho)"))
    tempo = parse(Float64, campos[2])
    isfinite(tempo) && tempo >= 0 ||
        throw(ArgumentError("Tempo de execucao invalido: $(caminho)"))
    return tempo
end

function comparar_metodos_por_distancia(pasta_picking=DIRETORIO_PICKING)
    heuristicas = ("abc_sku", "random", "coocorrencia")
    distancias = Dict(
        heuristica => _distancia_total(pasta_picking, heuristica)
        for heuristica in heuristicas
    )
    menor_distancia = minimum(values(distancias))
    melhores = [
        heuristica for heuristica in heuristicas
        if isapprox(distancias[heuristica], menor_distancia; atol=1e-8, rtol=1e-10)
    ]
    heuristica_menor_distancia = length(melhores) == 1 ? only(melhores) : "empate"
    tempos = Dict(
        heuristica => _tempo_execucao(pasta_picking, heuristica)
        for heuristica in heuristicas
    )
    menor_tempo = minimum(values(tempos))
    mais_rapidos = [
        heuristica for heuristica in heuristicas
        if isapprox(tempos[heuristica], menor_tempo; atol=1e-8, rtol=1e-10)
    ]
    heuristica_menor_tempo = length(mais_rapidos) == 1 ? only(mais_rapidos) : "empate"
    caminho_csv = joinpath(
        pasta_picking,
        "comparacao_distancia_abc_sku_random_coocorrencia.csv",
    )
    mkpath(pasta_picking)
    open(caminho_csv, "w") do arquivo
        println(arquivo, "heuristica,distancia_total,tempo_execucao_segundos")
        for heuristica in heuristicas
            println(
                arquivo,
                "$(heuristica),$(distancias[heuristica]),$(tempos[heuristica])",
            )
        end
    end

    for heuristica in heuristicas
        println(
            "Distancia total $(heuristica): $(distancias[heuristica]); " *
            "tempo: $(tempos[heuristica]) segundos",
        )
    end
    println("Menor distancia total: $(heuristica_menor_distancia)")
    println("Menor tempo de execucao: $(heuristica_menor_tempo)")
    println("Comparacao salva em: $(caminho_csv)")

    return (
        abc_sku=distancias["abc_sku"],
        random=distancias["random"],
        coocorrencia=distancias["coocorrencia"],
        tempos=tempos,
        menor_distancia=heuristica_menor_distancia,
        menor_tempo=heuristica_menor_tempo,
        caminho_csv=caminho_csv,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    pasta_picking = isempty(ARGS) ? DIRETORIO_PICKING : abspath(ARGS[1])
    comparar_metodos_por_distancia(pasta_picking)
end
