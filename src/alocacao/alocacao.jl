function _construir_grafo!(warehouse::Warehouse)
    isempty(warehouse.grafo.adjacencias) ||
        throw(ArgumentError("alocar! requer um grafo vazio"))
    n = length(warehouse.estantes)
    adjacencias = [Tuple{Int,Float64}[] for _ in 1:n]
    saida = warehouse.estantes[1]
    config = warehouse.config

    for indice in 2:n
        distancia = distancia_estantes(
            saida,
            warehouse.estantes[indice],
            config.largura_armazem,
            config.comprimento_armazem,
        )
        push!(adjacencias[1], (indice, Float64(distancia)))
        push!(adjacencias[indice], (1, Float64(distancia)))
    end
    warehouse.grafo.adjacencias = adjacencias
    return warehouse.grafo
end

function _distancias_saida(grafo::GrafoWarehouse)
    n = length(grafo.adjacencias)
    distancias = fill(Inf, n)
    visitados = falses(n)
    distancias[1] = 0.0

    for _ in 1:n
        atual = 0
        menor = Inf
        for indice in 1:n
            if !visitados[indice] && distancias[indice] < menor
                atual = indice
                menor = distancias[indice]
            end
        end
        atual == 0 && break
        visitados[atual] = true
        for (vizinho, peso) in grafo.adjacencias[atual]
            alternativa = distancias[atual] + peso
            alternativa < distancias[vizinho] && (distancias[vizinho] = alternativa)
        end
    end
    return distancias
end

function _volume_ocupado(estante::Estante, volumes)
    return sum(
        item.quantidade == 0 ? 0.0 : item.quantidade * something(volumes[item.id])
        for item in estante.itens;
        init=0.0,
    )
end

function _alocar_item!(warehouse, item, prateleiras, volumes)
    config = warehouse.config
    rack_capacity = config.capacidade_prateleira * config.prateleiras_por_estante
    max_racks = min(config.quantidade_maxima_estantes_item, length(prateleiras))

    for numero_racks in 1:max_racks
        por_estante = cld(item.quantidade, numero_racks)
        volume_necessario = por_estante * something(item.volume, 0.0)
        candidatos = Estante[]

        for estante in prateleiras
            length(estante.itens) < config.variedade_por_estante || continue
            ocupado = _volume_ocupado(estante, volumes)
            capacidade_livre = rack_capacity - ocupado
            capacidade_suficiente =
                isinf(rack_capacity) ||
                capacidade_livre + eps(max(1.0, capacidade_livre)) >= volume_necessario
            capacidade_suficiente ||
                continue
            push!(candidatos, estante)
        end
        length(candidatos) >= numero_racks || continue

        quociente, resto = divrem(item.quantidade, numero_racks)
        for indice in 1:numero_racks
            quantidade = quociente + (indice <= resto ? 1 : 0)
            push!(candidatos[indice].itens, ItemArmazenado(item.id, quantidade))
        end
        return
    end

    throw(ArgumentError(
        "Nao foi possivel alocar $(item.id) em ate $(config.quantidade_maxima_estantes_item) estantes",
    ))
end

function alocar!(warehouse::Warehouse, estoque, ::MetodoABC)
    isempty(warehouse.grafo.adjacencias) ||
        throw(ArgumentError("alocar! requer um Warehouse com grafo vazio"))

    ids = [item.id for item in estoque]
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("O estoque contem IDs duplicados"))
    all(
        item.quantidade >= 0 &&
        (item.volume === nothing ? item.quantidade == 0 :
         isfinite(item.volume) && item.volume > 0) &&
        item.frequencia_pedidos >= 0
        for item in estoque
    ) || throw(ArgumentError("O estoque contem quantidade, volume ou frequencia invalida"))
    all(isempty(estante.itens) for estante in warehouse.estantes) ||
        throw(ArgumentError("O Warehouse ja contem itens alocados"))
    capacidade_variedade =
        count(estante -> !estante.eh_saida, warehouse.estantes) *
        warehouse.config.variedade_por_estante
    length(ids) <= capacidade_variedade ||
        throw(ArgumentError("O Warehouse nao tem variedade suficiente para todos os IDs"))

    _construir_grafo!(warehouse)
    distancias = _distancias_saida(warehouse.grafo)
    indices_prateleiras = sort(
        filter(indice -> !warehouse.estantes[indice].eh_saida, eachindex(warehouse.estantes));
        by=indice -> (distancias[indice], warehouse.estantes[indice].id),
    )
    prateleiras = [warehouse.estantes[indice] for indice in indices_prateleiras]
    classes = _classes_abc(estoque, warehouse.config.abc_percentuais)
    ordem_classe = Dict(:A => 1, :B => 2, :C => 3)
    itens_ordenados = sort(
        collect(estoque);
        by=item -> (ordem_classe[classes[item.id]], -item.frequencia_pedidos, item.id),
    )
    volumes = Dict(item.id => item.volume for item in estoque)

    for item in itens_ordenados
        _alocar_item!(warehouse, item, prateleiras, volumes)
    end
    return warehouse
end
