struct ProdutoEstoque
    id::String
    quantidade::Int
    volume::Union{Nothing,Float64}
    frequencia_pedidos::Int
end

struct ItemArmazenado
    id::String
    quantidade::Int
end
