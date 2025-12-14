create or replace function abrir_funcion(
    p_id_sala INT,
    p_fecha_inicio DATE,
    p_hora_inicio TIME,
    p_id_pelicula INT
) returns int as $$
declare
    v_duracion INTERVAL;
    v_formato_sala CHAR(10);
    v_formato_pelicula CHAR(10);
    v_capacidad INT;
    v_fecha_hora_inicio TIMESTAMP := p_fecha_inicio + p_hora_inicio;
    v_fecha_hora_fin TIMESTAMP;
    v_conflicto INT;
    v_id_funcion INT;
    v_nuevo_id_funcion INT;
    v_nuevo_id_error INT;
begin
    -- 1. Validar sala
    select formato, capacidad_total into v_formato_sala, v_capacidad
    from sala_cine where id_sala = p_id_sala;

    if not found then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error (id_error, id_sala, f_inicio_funcion, id_pelicula, f_error, motivo)
        values (v_nuevo_id_error, p_id_sala, v_fecha_hora_inicio, p_id_pelicula, now(), 'id de sala no válido');
        RAISE NOTICE 'Error: id_sala % no válido', p_id_sala;
        return -1;
    end if;

    -- 2. Validar película
    select formato, duracion INTO v_formato_pelicula, v_duracion
    from pelicula WHERE id_pelicula = p_id_pelicula;

    if not found then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error (id_error, id_sala, f_inicio_funcion, id_pelicula, f_error, motivo)
        values (v_nuevo_id_error, p_id_sala, v_fecha_hora_inicio, p_id_pelicula, now(), 'id de película no válido');
        RAISE NOTICE 'Error: id_pelicula % no válido', p_id_pelicula;
        return -1;
    end if;

    -- 3. Validar horario
    if v_fecha_hora_inicio <= now() then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error (id_error, id_sala, f_inicio_funcion, id_pelicula, f_error, motivo)
        values (v_nuevo_id_error, p_id_sala, v_fecha_hora_inicio, p_id_pelicula, now(), 'no se permite abrir una nueva función con retroactividad');
        RAISE NOTICE 'Error: intento de abrir función con retroactividad (%).', v_fecha_hora_inicio;
        return -1;
    end if;

    -- 4. Validar solapamiento
    v_fecha_hora_fin := v_fecha_hora_inicio + v_duracion;

    select count(*) into v_conflicto
    from funcion
    where id_sala = p_id_sala
      and (p_fecha_inicio + p_hora_inicio, v_fecha_hora_fin)
          overlaps (fecha_inicio + hora_inicio, fecha_fin + hora_fin);

    if v_conflicto > 0 then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error (id_error, id_sala, f_inicio_funcion, id_pelicula, f_error, motivo)
        values (v_nuevo_id_error, p_id_sala, v_fecha_hora_inicio, p_id_pelicula, now(), 'no se permite solapar funciones en una sala');
        RAISE NOTICE 'Error: hay solapamiento de funciones en la sala %.', p_id_sala;
        return -1;
    end if;

    -- 5. Validar formato
    if v_formato_sala <> v_formato_pelicula then
        select coalesce(max(id_error), 0) + 1 into v_nuevo_id_error from error;
        insert into error (id_error, id_sala, f_inicio_funcion, id_pelicula, f_error, motivo)
        values (v_nuevo_id_error, p_id_sala, v_fecha_hora_inicio, p_id_pelicula, now(), 'sala no habilitada para el formato de la película');
        RAISE NOTICE 'Error: formatos incompatibles entre sala % y película %.', v_formato_sala, v_formato_pelicula;
        return -1;
    end if;

    -- 6. Insertar función
    select coalesce(max(id_funcion), 0) + 1 into v_nuevo_id_funcion from funcion;

    insert into funcion (
        id_funcion, id_sala, fecha_inicio, hora_inicio,
        fecha_fin, hora_fin, id_pelicula,
        butacas_disponible
    ) values (
        v_nuevo_id_funcion, p_id_sala, p_fecha_inicio, p_hora_inicio,
        (v_fecha_hora_fin)::date,
        (v_fecha_hora_fin)::time,
        p_id_pelicula, v_capacidad
    )
    returning id_funcion INTO v_id_funcion;

    RAISE NOTICE 'Función creada exitosamente con id %.', v_id_funcion;

    return v_id_funcion;

end;
$$ LANGUAGE plpgsql;
