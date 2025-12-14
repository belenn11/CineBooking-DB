create or replace procedure procesar_datos_de_prueba()
as $$
declare
    caso RECORD;
    resultado int;
    bol bool;
begin
    --Recorremos los TC y los ejecutamos
    for caso in
        select * from datos_de_prueba order by id_orden
    loop
        case caso.operacion
            when 'nueva funcion' then
                select abrir_funcion(
                    caso.id_sala,
                    (caso.f_inicio_funcion)::date,
                    (caso.f_inicio_funcion)::time,
                    caso.id_pelicula
                ) into resultado;
                RAISE NOTICE 'Se intentó abrir función, resultado: %', resultado;

            when 'reserva butaca' then
                select reservar_butaca(
                    caso.id_funcion,
                    caso.id_cliente,
                    caso.nro_fila,
                    caso.nro_butaca
                ) into bol;
                RAISE NOTICE 'Se intentó reservar butaca, resultado: %', bol;

            when 'compra butaca' then
                select comprar_butaca(
                    caso.id_funcion,
                    caso.id_cliente,
                    caso.nro_fila,
                    caso.nro_butaca
                ) into bol;
                RAISE NOTICE 'Se intentó comprar butaca, resultado: %', bol;

            when 'anulacion reserva' then
                select anular_reserva(
                    caso.id_funcion,
                    caso.id_cliente,
                    caso.nro_fila,
                    caso.nro_butaca
                ) into bol;
                RAISE NOTICE 'Se intentó anular reserva, resultado: %', bol;

            else
                RAISE NOTICE 'Operación desconocida en fila %: %', caso.id_orden, caso.operacion;
        end case;
    end loop;
end $$ language plpgsql;
