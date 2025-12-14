create or replace function anular_reserva(
    p_id_funcion INT,
    p_id_cliente INT,
    p_nro_fila INT,
    p_nro_butaca INT
) returns boolean as $$
declare
    v_id_sala int;
    v_nro_filas int;
    v_nro_butacas int;
    v_estado text;
    v_cliente int;
    v_nuevo_id_error int;
begin
    --Buscamos que exista la función
    select id_sala into v_id_sala
    from funcion
    where id_funcion = p_id_funcion;

    if not found then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, now(), 'id de función no válido');
        return false;
    end if;

    --Vemos que haya butacas 
    select nro_filas, nro_butacas_por_fila into v_nro_filas, v_nro_butacas
    from sala_cine where id_sala = v_id_sala;

    if not found or p_nro_fila < 1 or p_nro_fila > v_nro_filas
       or p_nro_butaca < 1 or p_nro_butaca > v_nro_butacas then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, now(), 'no existe número de fila o butaca');
        return false;
    end if;

    --Verificamos que la butaca esté reservada por el cliente
    select estado, id_cliente into v_estado, v_cliente
    from butaca_por_funcion
    where id_funcion = p_id_funcion and nro_fila = p_nro_fila and nro_butaca = p_nro_butaca;

    if not found or v_estado <> 'reservada' or v_cliente <> p_id_cliente then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, now(), 'butaca no reservada por el cliente');
        return false;
    end if;

    --eliminamos la reserva de la butaca
    update butaca_por_funcion
    set estado = 'anulada'
    where id_funcion = p_id_funcion and nro_fila = p_nro_fila and nro_butaca = p_nro_butaca;

    update funcion
    set butacas_disponible = butacas_disponible + 1
    where id_funcion = p_id_funcion;

    return true;
end;
$$ LANGUAGE plpgsql;

