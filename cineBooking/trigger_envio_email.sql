create or replace function trigger_envio_email()
returns trigger as $$
declare
    v_email TEXT;
    v_id_email INT;
begin
    -- Se crea el mail si es necesario
    if new.estado in ('reservada', 'comprada') then
        select email into v_email
        from cliente
        where id_cliente = new.id_cliente;

        select coalesce(max(id_email), 0) + 1 into v_id_email from envio_email;

        insert into envio_email(id_email,f_generacion, email_cliente, asunto, cuerpo, f_envio, estado)
        values (
			v_id_email,
            NOW(),
            v_email,
            'Notificación de reserva',
            FORMAT('Su butaca (%s,%s) para la función %s fue %s.',
                   new.nro_fila, new.nro_butaca, new.id_funcion, new.estado),
            null,
            'pendiente'
        );
    end if;
    return new;
end;
$$ language plpgsql;

--Setteamos cuando se ejecuta el trigger
create or replace trigger tr_envio_email
after insert or update on butaca_por_funcion
for each row
execute function trigger_envio_email();
