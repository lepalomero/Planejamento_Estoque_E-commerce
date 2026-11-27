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

function _alocar_item_incremental!(warehouse, item, prateleiras, volumes)
    config = warehouse.config
    rack_capacity = config.capacidade_prateleira * config.prateleiras_por_estante
    locais_existentes = [
        estante for estante in prateleiras
        if any(alocado -> alocado.id == item.id, estante.itens)
    ]
    max_racks = min(config.quantidade_maxima_estantes_item, length(prateleiras))
    length(locais_existentes) <= max_racks || throw(ArgumentError(
        "O item $(item.id) ja excede o limite de estantes",
    ))

    candidatos = [
        estante for estante in prateleiras
        if any(alocado -> alocado.id == item.id, estante.itens) ||
           length(estante.itens) < config.variedade_por_estante
    ]
    novos_locais_permitidos = max_racks - length(locais_existentes)
    novos_locais = filter(
        estante -> !any(alocado -> alocado.id == item.id, estante.itens),
        candidatos,
    )
    candidatos = vcat(locais_existentes, novos_locais[1:min(end, novos_locais_permitidos)])

    restante = item.quantidade
    plano = Tuple{Estante,Int}[]
    for estante in candidatos
        restante == 0 && break
        livre = rack_capacity - _volume_ocupado(estante, volumes)
        unidades_livres = isinf(rack_capacity) ? restante :
            max(0, floor(Int, (livre + eps(max(1.0, livre))) / something(item.volume)))
        quantidade = min(restante, unidades_livres)
        quantidade > 0 && push!(plano, (estante, quantidade))
        restante -= quantidade
    end
    restante == 0 || throw(ArgumentError(
        "Nao foi possivel repor $(item.id) em ate $(config.quantidade_maxima_estantes_item) estantes",
    ))

    for (estante, quantidade) in plano
        indice = findfirst(alocado -> alocado.id == item.id, estante.itens)
        if indice === nothing
            push!(estante.itens, ItemArmazenado(item.id, quantidade))
        else
            anterior = estante.itens[indice]
            estante.itens[indice] = ItemArmazenado(item.id, anterior.quantidade + quantidade)
        end
    end
    return
end

function _unidades_cabem(item, estante, rack_capacity, volumes, restante)
    isinf(rack_capacity) && return restante
    capacidade_livre = max(0.0, rack_capacity - _volume_ocupado(estante, volumes))
    return max(
        0,
        floor(Int, (capacidade_livre + eps(max(1.0, capacidade_livre))) /
                   something(item.volume)),
    )
end

function _alocar_item_aleatorio!(warehouse, item, prateleiras, volumes, rng)
    config = warehouse.config
    rack_capacity = config.capacidade_prateleira * config.prateleiras_por_estante
    max_racks = min(config.quantidade_maxima_estantes_item, length(prateleiras))
    existentes = filter(
        estante -> any(alocado -> alocado.id == item.id, estante.itens),
        prateleiras,
    )
    length(existentes) <= max_racks || throw(ArgumentError(
        "O item $(item.id) ja excede o limite de estantes",
    ))
    shuffle!(rng, existentes)

    usados = Set(estante.id for estante in existentes)
    plano = Tuple{Estante,Int}[]
    restante = item.quantidade
    for estante in existentes
        restante == 0 && break
        quantidade = min(
            restante,
            _unidades_cabem(item, estante, rack_capacity, volumes, restante),
        )
        quantidade > 0 && push!(plano, (estante, quantidade))
        restante -= quantidade
    end

    candidatos = [
        estante for estante in prateleiras
        if !(estante.id in usados) &&
           length(estante.itens) < config.variedade_por_estante
    ]
    shuffle!(rng, candidatos)
    for estante in candidatos
        restante == 0 && break
        length(usados) >= max_racks && break
        quantidade = min(
            restante,
            _unidades_cabem(item, estante, rack_capacity, volumes, restante),
        )
        quantidade == 0 && continue
        push!(plano, (estante, quantidade))
        push!(usados, estante.id)
        restante -= quantidade
    end
    restante == 0 || throw(ArgumentError(
        "Nao foi possivel alocar $(item.id) em ate $(config.quantidade_maxima_estantes_item) estantes aleatorias",
    ))

    for (estante, quantidade) in plano
        indice = findfirst(alocado -> alocado.id == item.id, estante.itens)
        if indice === nothing
            push!(estante.itens, ItemArmazenado(item.id, quantidade))
        else
            anterior = estante.itens[indice]
            estante.itens[indice] = ItemArmazenado(item.id, anterior.quantidade + quantidade)
        end
    end
    return
end

function alocar!(warehouse::Warehouse, estoque, metodo::MetodoAlocacao)
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
    itens_ordenados = _itens_ordenados(estoque, warehouse.config.abc_percentuais, metodo)
    estoque_vazio = all(isempty(estante.itens) for estante in warehouse.estantes)
    if estoque_vazio
        capacidade_variedade =
            count(estante -> !estante.eh_saida, warehouse.estantes) *
            warehouse.config.variedade_por_estante
        count(item -> item.quantidade > 0, estoque) <= capacidade_variedade ||
            throw(ArgumentError("O Warehouse nao tem variedade suficiente para todos os IDs"))
    end

    for item in estoque
        if haskey(warehouse.volumes, item.id) &&
           warehouse.volumes[item.id] !== item.volume
            throw(ArgumentError("O volume do item $(item.id) mudou durante a alocacao"))
        end
        warehouse.volumes[item.id] = item.volume
        warehouse.frequencias_pedidos[item.id] = item.frequencia_pedidos
    end

    if isempty(warehouse.grafo.adjacencias)
        _construir_grafo!(warehouse)
    else
        length(warehouse.grafo.adjacencias) == length(warehouse.estantes) ||
            throw(ArgumentError("O grafo do Warehouse nao corresponde as estantes"))
    end

    distancias = _distancias_saida(warehouse.grafo)
    indices_prateleiras = sort(
        filter(indice -> !warehouse.estantes[indice].eh_saida, eachindex(warehouse.estantes));
        by=indice -> (distancias[indice], warehouse.estantes[indice].id),
    )
    prateleiras = [warehouse.estantes[indice] for indice in indices_prateleiras]
    for item in itens_ordenados
        item.quantidade == 0 && continue
        if metodo isa MetodoAleatorio
            _alocar_item_aleatorio!(warehouse, item, prateleiras, warehouse.volumes, metodo.rng)
        elseif any(
                alocado -> alocado.id == item.id,
                Iterators.flatten(estante.itens for estante in prateleiras),
            )
            _alocar_item_incremental!(warehouse, item, prateleiras, warehouse.volumes)
        else
            _alocar_item!(warehouse, item, prateleiras, warehouse.volumes)
        end
    end
    return warehouse
end
