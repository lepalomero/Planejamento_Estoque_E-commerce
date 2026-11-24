using Dates
using Random

function _valor_linha(linha, coluna::Symbol)
    hasproperty(linha, coluna) && return getproperty(linha, coluna)
    if linha isa AbstractDict
        haskey(linha, coluna) && return linha[coluna]
        haskey(linha, String(coluna)) && return linha[String(coluna)]
    end
    throw(ArgumentError("Coluna obrigatoria ausente: $(coluna)"))
end

function _data_pedido(valor)
    valor isa DateTime && return valor
    valor isa Date && return DateTime(valor)
    texto = string(valor)
    if length(texto) == 10
        return DateTime(Date(texto, dateformat"yyyy-mm-dd"))
    elseif occursin('T', texto)
        return DateTime(texto, dateformat"yyyy-mm-ddTHH:MM:SS")
    end
    return DateTime(texto, dateformat"yyyy-mm-dd HH:MM:SS")
end

function _ids_pedido(valor)
    valor === missing && throw(ArgumentError("ids_dos_produtos nao pode estar ausente"))
    return filter(id -> !isempty(id), strip.(split(string(valor), ';')))
end

function _dados_produtos(produtos)
    resultado = Dict{String,Union{Nothing,Float64}}()
    for produto in produtos
        id = string(_valor_linha(produto, :id))
        isempty(id) && throw(ArgumentError("Produto com id vazio"))
        haskey(resultado, id) && throw(ArgumentError("ID de produto duplicado: $(id)"))
        dimensoes = (
            _valor_linha(produto, :altura),
            _valor_linha(produto, :largura),
            _valor_linha(produto, :espessura),
        )
        if any(ismissing, dimensoes)
            resultado[id] = nothing
            continue
        end

        altura, largura, comprimento = Float64.(dimensoes)
        volume = comprimento * largura * altura
        isfinite(volume) && volume > 0 ||
            throw(ArgumentError("Volume invalido para o produto $(id)"))
        resultado[id] = volume
    end
    return resultado
end

function _escolher_extra(rng, candidatos, frequencias, quantidades)
    logpesos = [
        log(frequencias[id]) - 0.5 * log(quantidades[id] + 1) + 0.25 * randn(rng)
        for id in candidatos
    ]
    maximo = maximum(logpesos)
    pesos = exp.(logpesos .- maximo)
    sorteio = rand(rng) * sum(pesos)
    acumulado = 0.0
    for (indice, id) in enumerate(candidatos)
        acumulado += pesos[indice]
        sorteio <= acumulado && return id
    end
    return candidatos[end]
end

function gerar_estoque(pedidos, produtos, config::ConfigEstoque)
    dados_produtos = _dados_produtos(produtos)
    isempty(dados_produtos) && throw(ArgumentError("A lista de produtos esta vazia"))
    isempty(pedidos) && throw(ArgumentError("A lista de pedidos esta vazia"))

    datas = [_data_pedido(_valor_linha(pedido, :data_do_pedido)) for pedido in pedidos]
    data_final = maximum(datas)
    data_inicial = data_final - Day(30)
    quantidades = Dict(id => 0 for id in keys(dados_produtos))
    frequencias = Dict(id => 0 for id in keys(dados_produtos))

    for (pedido, data) in zip(pedidos, datas)
        data_inicial <= data <= data_final || continue
        ids = _ids_pedido(_valor_linha(pedido, :ids_dos_produtos))
        for id in ids
            haskey(dados_produtos, id) ||
                throw(ArgumentError("Produto $(id) de um pedido nao existe em produtos.csv"))
            quantidades[id] += 1
        end
        for id in unique(ids)
            frequencias[id] += 1
        end
    end

    ids = sort!(collect(keys(dados_produtos)))
    volumes = dados_produtos
    for id in ids
        quantidades[id] > 0 && volumes[id] === nothing &&
            throw(ArgumentError("Dimensoes ausentes para o produto demandado $(id)"))
    end

    if isinf(config.capacidade_prateleira)
        capacidade_itens = config.n_estantes * config.variedade_por_estante
        length(ids) <= capacidade_itens || begin
            @warn "Capacidade de variedade insuficiente para armazenar todos os IDs." ids=length(ids) capacidade=capacidade_itens
            throw(ArgumentError("Numero de IDs distintos excede a capacidade de variedade"))
        end
    else
        capacidade_total =
            config.capacidade_prateleira *
            config.prateleiras_por_estante *
            config.n_estantes
        volume_atual = sum(
            volumes[id] === nothing ? 0.0 : volumes[id] * quantidades[id]
            for id in ids
        )
        ocupacao = volume_atual / capacidade_total

        ocupacao <= config.ocupacao_max || begin
            @warn "A demanda do ultimo mes excede a ocupacao maxima do armazem." ocupacao=ocupacao limite=config.ocupacao_max
            throw(ArgumentError("A demanda minima excede a ocupacao maxima"))
        end

        if ocupacao < config.ocupacao_min
            alvo = config.ocupacao_min * capacidade_total
            limite = config.ocupacao_max * capacidade_total
            rng = MersenneTwister(config.semente)

            while volume_atual < alvo
                candidatos = [
                    id for id in ids
                    if frequencias[id] > 0 &&
                       volumes[id] !== nothing &&
                       floor(Int, (limite - volume_atual) / volumes[id]) >= 1
                ]
                isempty(candidatos) && begin
                    @warn "Nao ha estoque adicional viavel para atingir a ocupacao minima." ocupacao=(volume_atual / capacidade_total) limite=config.ocupacao_min
                    throw(ArgumentError("Nao foi possivel atingir a ocupacao minima sem exceder a maxima"))
                end

                escolhido = _escolher_extra(rng, candidatos, frequencias, quantidades)
                unidades_necessarias =
                    max(1, ceil(Int, (alvo - volume_atual) / volumes[escolhido]))
                unidades_permitidas =
                    floor(Int, (limite - volume_atual) / volumes[escolhido])
                adicionar = min(unidades_necessarias, unidades_permitidas)
                quantidades[escolhido] += adicionar
                volume_atual += adicionar * volumes[escolhido]
            end
        end
    end

    return [
        ProdutoEstoque(id, quantidades[id], volumes[id], frequencias[id])
        for id in ids
    ]
end
