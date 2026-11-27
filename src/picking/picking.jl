using Dates

const _ARQUIVOS_PICKING_FIXOS = ("estoque_inicial.csv", "grafo_inicial.csv")
const _PREFIXOS_ARQUIVOS_PICKING = (
    "estoque_inicial_",
    "estoque_mensal_",
    "grafo_inicial_",
    "grafo_wave_",
    "rota_wave_",
    "itens_retirados_wave_",
    "distancia_wave_",
    "tempo_execucao_",
)

function limpar_saida_picking!(pasta_saida)
    mkpath(pasta_saida)
    for nome in readdir(pasta_saida)
        arquivo_csv = endswith(nome, ".csv") &&
            (nome in _ARQUIVOS_PICKING_FIXOS ||
             any(prefixo -> startswith(nome, prefixo), _PREFIXOS_ARQUIVOS_PICKING))
        caminho = joinpath(pasta_saida, nome)
        arquivo_csv && isfile(caminho) && rm(caminho)
    end
    return pasta_saida
end

function _valor_csv(valor)
    texto = string(valor)
    return occursin(r"[,\r\n\"]", texto) ?
        "\"" * replace(texto, "\"" => "\"\"") * "\"" :
        texto
end

function _salvar_csv(caminho, cabecalho, linhas)
    mkpath(dirname(caminho))
    open(caminho, "w") do arquivo
        println(arquivo, join(_valor_csv.(cabecalho), ','))
        for linha in linhas
            valores = linha isa NamedTuple ? Tuple(linha) : linha
            println(arquivo, join(_valor_csv.(valores), ','))
        end
    end
    return caminho
end

function _linhas_estoque(warehouse::Warehouse)
    return [
        (estante.id, item.id, item.quantidade, get(warehouse.volumes, item.id, nothing))
        for estante in warehouse.estantes
        for item in estante.itens
    ]
end

function salvar_estoque(caminho, warehouse::Warehouse)
    return _salvar_csv(
        caminho,
        ("estante_id", "item_id", "quantidade", "volume_unitario"),
        _linhas_estoque(warehouse),
    )
end

function salvar_grafo(caminho, warehouse::Warehouse)
    linhas = [
        (
            origem,
            destino,
            distancia,
            join(
                (
                    "$(item.id):$(item.quantidade)"
                    for item in warehouse.estantes[origem].itens
                ),
                ';',
            ),
        )
        for origem in eachindex(warehouse.grafo.adjacencias)
        for (destino, distancia) in warehouse.grafo.adjacencias[origem]
    ]
    return _salvar_csv(
        caminho,
        ("origem", "destino", "distancia", "estoque_origem"),
        linhas,
    )
end

mutable struct CaminhaoPicking
    id::Int
    quantidades::Dict{String,Int}
    volume::Float64
    estantes_visitadas::Vector{Int}
end

function _linha_nao_carregada(item_id, falta, motivo)
    return (
        caminhao_id="",
        item_id=item_id,
        quantidade=0,
        volume_total=0.0,
        estante_id="",
        falta=falta,
        motivo=motivo,
    )
end

function _planejar_cargas(warehouse::Warehouse, demandas)
    capacidade_volume = warehouse.config.capacidade_volume_caminhao
    capacidade_skus = warehouse.config.capacidade_quantidade_caminhao
    capacidade_volume === nothing && throw(ArgumentError(
        "capacidade_volume_caminhao deve estar configurada para o picking",
    ))
    capacidade_skus === nothing && throw(ArgumentError(
        "capacidade_quantidade_caminhao deve estar configurada para o picking",
    ))

    estoque_disponivel = Dict{String,Int}()
    for estante in warehouse.estantes
        for item in estante.itens
            estoque_disponivel[item.id] =
                get(estoque_disponivel, item.id, 0) + item.quantidade
        end
    end

    ids = sort!(
        collect(keys(demandas));
        by=item_id -> (
            get(warehouse.volumes, item_id, nothing) === nothing ?
            Inf : -warehouse.volumes[item_id],
            item_id,
        ),
    )
    caminhoes = CaminhaoPicking[]
    nao_carregados = NamedTuple[]

    for item_id in ids
        solicitado = demandas[item_id]
        solicitado isa Integer && solicitado >= 0 ||
            throw(ArgumentError("Demanda inteira nao negativa esperada para $(item_id)"))
        solicitado == 0 && continue

        disponivel = get(estoque_disponivel, item_id, 0)
        quantidade_carregavel = min(solicitado, disponivel)
        if quantidade_carregavel < solicitado
            push!(
                nao_carregados,
                _linha_nao_carregada(
                    item_id,
                    solicitado - quantidade_carregavel,
                    "estoque_insuficiente",
                ),
            )
        end
        quantidade_carregavel == 0 && continue

        volume_unitario = get(warehouse.volumes, item_id, nothing)
        if volume_unitario === nothing || !isfinite(volume_unitario) ||
           volume_unitario <= 0
            push!(
                nao_carregados,
                _linha_nao_carregada(
                    item_id,
                    quantidade_carregavel,
                    "volume_indisponivel",
                ),
            )
            continue
        end
        if volume_unitario > capacidade_volume
            push!(
                nao_carregados,
                _linha_nao_carregada(
                    item_id,
                    quantidade_carregavel,
                    "capacidade_volume",
                ),
            )
            continue
        end

        restante = quantidade_carregavel
        while restante > 0
            if isempty(caminhoes)
                push!(
                    caminhoes,
                    CaminhaoPicking(1, Dict{String,Int}(), 0.0, Int[]),
                )
            end

            caminhao = last(caminhoes)
            sku_novo = !haskey(caminhao.quantidades, item_id)
            espaco_insuficiente =
                caminhao.volume + volume_unitario >
                capacidade_volume + eps(max(1.0, Float64(capacidade_volume)))
            if (sku_novo && length(caminhao.quantidades) >= capacidade_skus) ||
               espaco_insuficiente
                push!(
                    caminhoes,
                    CaminhaoPicking(length(caminhoes) + 1, Dict{String,Int}(), 0.0, Int[]),
                )
                caminhao = last(caminhoes)
            end

            unidades_cabem = floor(Int, (
                capacidade_volume - caminhao.volume +
                eps(max(1.0, Float64(capacidade_volume)))
            ) / volume_unitario)
            if unidades_cabem == 0
                push!(
                    caminhoes,
                    CaminhaoPicking(length(caminhoes) + 1, Dict{String,Int}(), 0.0, Int[]),
                )
                caminhao = last(caminhoes)
                unidades_cabem = floor(Int, Float64(capacidade_volume) / volume_unitario)
            end
            unidades_cabem > 0 || throw(ArgumentError(
                "O item $(item_id) nao cabe na capacidade volumetrica do caminhao",
            ))

            carregar = min(restante, unidades_cabem)
            caminhao.quantidades[item_id] =
                get(caminhao.quantidades, item_id, 0) + carregar
            caminhao.volume += carregar * volume_unitario
            restante -= carregar
        end
    end

    for motivo in ("estoque_insuficiente", "capacidade_volume", "volume_indisponivel")
        itens_afetados = unique([
            linha.item_id for linha in nao_carregados if linha.motivo == motivo
        ])
        isempty(itens_afetados) || @warn "Itens nao carregados na wave" motivo=motivo itens=itens_afetados
    end

    return caminhoes, nao_carregados
end

function _retirar_cargas!(warehouse::Warehouse, caminhoes)
    linhas = NamedTuple[]
    for caminhao in caminhoes
        for item_id in sort!(collect(keys(caminhao.quantidades)))
            restante = caminhao.quantidades[item_id]
            volume_unitario = something(warehouse.volumes[item_id])

            for estante in warehouse.estantes
                estante.eh_saida && continue
                indice = findfirst(item -> item.id == item_id, estante.itens)
                indice === nothing && continue

                armazenado = estante.itens[indice]
                retirado = min(restante, armazenado.quantidade)
                retirado == 0 && continue

                if retirado == armazenado.quantidade
                    deleteat!(estante.itens, indice)
                else
                    estante.itens[indice] =
                        ItemArmazenado(item_id, armazenado.quantidade - retirado)
                end

                push!(
                    linhas,
                    (
                        caminhao_id=caminhao.id,
                        item_id=item_id,
                        quantidade=retirado,
                        volume_total=retirado * volume_unitario,
                        estante_id=estante.id,
                        falta=0,
                        motivo="",
                    ),
                )
                push!(caminhao.estantes_visitadas, estante.id)
                restante -= retirado
                restante == 0 && break
            end

            restante == 0 || throw(ArgumentError(
                "Estoque mudou durante a separacao do caminhao $(caminhao.id)",
            ))
        end
        unique!(caminhao.estantes_visitadas)
    end

    return linhas
end

function executar_picking_wave!(
    warehouse::Warehouse,
    semana::Date,
    demandas,
    pasta_saida;
    sufixo_metodo="",
)
    caminhoes, nao_carregados = _planejar_cargas(warehouse, demandas)
    linhas_itens = _retirar_cargas!(warehouse, caminhoes)
    append!(linhas_itens, nao_carregados)
    sufixo = Dates.format(semana, dateformat"yyyy-mm-dd")

    if pasta_saida !== nothing
        salvar_grafo(
            joinpath(
                pasta_saida,
                _sufixar_arquivo("grafo_wave_$(sufixo).csv", sufixo_metodo),
            ),
            warehouse,
        )

        linhas_rota = NamedTuple[]
        linhas_distancia = NamedTuple[]
        for caminhao in caminhoes
            rota, distancia = rota_picking(warehouse, caminhao.estantes_visitadas)
            for (ordem, estante_id) in enumerate(rota)
                estante = warehouse.estantes[estante_id + 1]
                push!(
                    linhas_rota,
                    (
                        caminhao_id=caminhao.id,
                        ordem=ordem,
                        estante_id=estante_id,
                        posicao_x=estante.posicao[1],
                        posicao_y=estante.posicao[2],
                    ),
                )
            end
            push!(
                linhas_distancia,
                (
                    semana=semana,
                    caminhao_id=caminhao.id,
                    distancia_percorrida=distancia,
                    estantes_visitadas=length(caminhao.estantes_visitadas),
                    skus=length(caminhao.quantidades),
                    quantidade=sum(values(caminhao.quantidades)),
                    volume_total=caminhao.volume,
                ),
            )
        end
        _salvar_csv(
            joinpath(
                pasta_saida,
                _sufixar_arquivo("rota_wave_$(sufixo).csv", sufixo_metodo),
            ),
            ("caminhao_id", "ordem", "estante_id", "posicao_x", "posicao_y"),
            linhas_rota,
        )
        _salvar_csv(
            joinpath(
                pasta_saida,
                _sufixar_arquivo("itens_retirados_wave_$(sufixo).csv", sufixo_metodo),
            ),
            ("caminhao_id", "item_id", "quantidade_retirada", "volume_total", "estante_id", "falta", "motivo"),
            linhas_itens,
        )
        _salvar_csv(
            joinpath(
                pasta_saida,
                _sufixar_arquivo("distancia_wave_$(sufixo).csv", sufixo_metodo),
            ),
            ("semana", "caminhao_id", "distancia_percorrida", "estantes_visitadas", "skus", "quantidade", "volume_total"),
            linhas_distancia,
        )
    end

    return (caminhoes=caminhoes, itens=linhas_itens)
end
