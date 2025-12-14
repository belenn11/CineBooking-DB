create or replace function comprar_butaca(
    p_id_funcion INT,
    p_id_cliente INT,
    p_nro_fila   INT,
    p_nro_butaca INT
) returns boolean
language plpgsql
as $$
declare
    v_id_sala        INT;
    v_nro_filas      INT;
    v_nro_butacas    INT;
    v_estado_actual  CHAR(15);
    v_cliente_actual INT;
    v_previously_reserved BOOLEAN := FALSE;
    v_nuevo_id_error INT;
begin

    --Chequeamos que la función exista y obtenemos la sala
    select f.id_sala
      into v_id_sala
      from funcion f
     where f.id_funcion = p_id_funcion
     for update;

    if not found then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error ( id_error, id_funcion, nro_fila, nro_butaca,
                           id_cliente, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_nro_fila, p_nro_butaca,
                p_id_cliente, clock_timestamp(), '?id de función no válido');
        return false;
    end if;

    --Chequeamos si el asiento existe
    select s.nro_filas, s.nro_butacas_por_fila
      into v_nro_filas, v_nro_butacas
      from sala_cine s
     where s.id_sala = v_id_sala;

    if p_nro_fila < 1 or p_nro_fila > v_nro_filas
       OR p_nro_butaca < 1 or p_nro_butaca > v_nro_butacas then       
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error (id_error, id_sala, id_funcion, nro_fila, nro_butaca,
                           id_cliente, f_error, motivo)
        values (v_id_sala, p_id_funcion, p_nro_fila, p_nro_butaca,
                p_id_cliente, clock_timestamp(), '?no existe número de fila ó butaca');
        return false;
    end if;

    --Chequeamos si la butaca está reservada y por quién
    select estado, id_cliente
      into v_estado_actual, v_cliente_actual
      from butaca_por_funcion
     where id_funcion = p_id_funcion
       and nro_fila   = p_nro_fila
       and nro_butaca = p_nro_butaca
     for update;

    if found then
        if v_estado_actual in ('reservada','comprada')
           and v_cliente_actual <> p_id_cliente then
            select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
            insert into error ( id_error, id_sala, id_funcion, nro_fila, nro_butaca,
                               id_cliente, f_error, motivo)
            values (v_nuevo_id_error, v_id_sala, p_id_funcion, p_nro_fila, p_nro_butaca,
                    p_id_cliente, clock_timestamp(), '?butaca ocupada por otro cliente');
            return false;
        end if;

        if v_estado_actual = 'reservada' and v_cliente_actual = p_id_cliente then
            v_previously_reserved := true;
        end if;

        update butaca_por_funcion
           set estado      = 'comprada',
               id_cliente  = p_id_cliente
         where id_funcion  = p_id_funcion
           and nro_fila    = p_nro_fila
           and nro_butaca  = p_nro_butaca;
    else

    -- Si la butaca no se usa, la compramos
        insert into butaca_por_funcion (id_funcion, nro_fila, nro_butaca, id_cliente, estado)
        values (p_id_funcion, p_nro_fila, p_nro_butaca, p_id_cliente, 'comprada');
    end if;

    if not v_previously_reserved then
        update funcion
           set butacas_disponible = butacas_disponible - 1
         where id_funcion = p_id_funcion;
    end if;

    return true;
end;
$$;

commit;

