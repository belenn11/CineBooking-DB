create or replace function reservar_butaca(
    p_id_funcion INT,
    p_id_cliente INT,
    p_nro_fila INT,
    p_nro_butaca INT
) returns boolean as $$
declare
    v_id_sala INT;
    v_nro_filas INT;
    v_nro_butacas INT;
    v_disponibles INT;
    v_estado_existente TEXT;
    v_encontrada BOOLEAN := FALSE;
    v_nuevo_id_error INT;
begin
    select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;

    -- 1. Validar función
    select id_sala, butacas_disponible into v_id_sala, v_disponibles
    from funcion
    where id_funcion = p_id_funcion;

    if not found then
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, NOW(), 'Función no válida');
        return false;
    end if;

    -- 2. Validar fila y butaca según sala
    select nro_filas, nro_butacas_por_fila into v_nro_filas, v_nro_butacas
    from sala_cine
    where id_sala = v_id_sala;

    if not found or p_nro_fila < 1 or p_nro_fila > v_nro_filas
       or p_nro_butaca < 1 or p_nro_butaca > v_nro_butacas then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, NOW(), 'Butaca o fila fuera de rango');
        return false;
    end if;

    -- 3. Validar disponibilidad
    if v_disponibles <= 0 then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, NOW(), 'Sala llena');
        return false;
    end if;

    -- 4. Verificar si ya hay un registro para esa butaca
    select estado into v_estado_existente
    from butaca_por_funcion
    where id_funcion = p_id_funcion
      and nro_fila = p_nro_fila
      and nro_butaca = p_nro_butaca;

    if found then
        v_encontrada := true;
    end if;

    -- Si ya estaba reservada o comprada, no se puede volver a reservar
    if v_encontrada and v_estado_existente in ('reservada', 'comprada') then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error(id_error, id_funcion, id_cliente, nro_fila, nro_butaca, f_error, motivo)
        values (v_nuevo_id_error, p_id_funcion, p_id_cliente, p_nro_fila, p_nro_butaca, NOW(), 'Butaca no disponible');
        return false;
    end if;

    -- 5. Insertar o actualizar reserva
    if v_encontrada then
        update butaca_por_funcion
        set estado = 'reservada', id_cliente = p_id_cliente
        where id_funcion = p_id_funcion and nro_fila = p_nro_fila and nro_butaca = p_nro_butaca;
    else
        insert into butaca_por_funcion(id_funcion, nro_fila, nro_butaca, id_cliente, estado)
        values (p_id_funcion, p_nro_fila, p_nro_butaca, p_id_cliente, 'reservada');
    end if;

    -- 6. Restar butaca disponible
    update funcion
    set butacas_disponible = butacas_disponible - 1
    where id_funcion = p_id_funcion;

    return true;
end;
$$ language plpgsql;
