#require "#{Rails.root}/lib/egg_autotests/egg_autotests_list.rb"

class IA_JPMorgan_GIS_ZKH

  def initialize(pass_menu_color, fail_menu_color, not_find_xml, not_receive_answer, egg_version, try_count)
    @pass_menu_color = pass_menu_color
    @fail_menu_color = fail_menu_color
    @not_find_xml = not_find_xml
    @not_receive_answer = not_receive_answer
    @egg_version = egg_version
    @try_count = try_count

    @menu_name = 'ИА JPMorgan (ГИС ЖКХ)'
    @category = Category.find_by_category_name('ИА ГИС ЖКХ JPMorgan')
    @dir_outbound = 'C:/data/INAD_GISZHKH/inbox'
    @dir_inbound = 'C:/data/INAD_GISZHKH/outbox'
    @result = Hash.new
    @functional = "Проверка ИА JPMorgan (ГИС ЖКХ)"
    @orderid = "C022811160002323002016112804#{Random.rand(1000..9000)}"
    @expected_result = 'UpdateDate' # Текст, который должен быть в XML, если она успешна
  end

  def change_transportguid(functional, transport_guid)
    30.times do
      $egg_integrator.core_in_ufebs_jpm.any? ? (break) : (sleep 1)
    end
    if $egg_integrator.core_in_ufebs_jpm.any?
      xml_from_ia = $egg_integrator.core_in_ufebs_jpm.first[:body]
      $log_egg.write_to_browser("Перехватили сообщение от ИА к ядру. CorrelationID: #{$egg_integrator.core_in_ufebs_jpm.first[:correlation_id]}")
      $log_egg.write_to_log(functional, "Перехватили сообщение от ИА к ядру. CorrelationID: #{$egg_integrator.core_in_ufebs_jpm.first[:correlation_id]}", xml_from_ia)
    else
      $log_egg.write_to_browser("Сообщение не дошло до ядра")
      $log_egg.write_to_log(functional, "Проверка сообщения в очереди core_sa", "Сообщение не дошло до ядра")
      return
      # count +=1
      # next
    end
    if functional.include?('GIS_ZKH_Payment_Cancellation')
      $egg_integrator.send_to_core($egg_integrator.core_in_ufebs_jpm.first[:body], $egg_integrator.core_in_ufebs_jpm.first[:correlation_id])
      $log_egg.write_to_browser("Отправили сообщение в ядро без изменений")
      $log_egg.write_to_log(functional, "Отправили сообщение в ядро без изменений", $egg_integrator.core_in_ufebs_jpm.first[:body])
    else
      decode_rexml_request = get_decode_core_request(xml_from_ia)
      decode_rexml_request.root.add_element('gis:TransportGUID').text = transport_guid
      xml_to_sa = get_encode_core_request(functional, xml_from_ia, decode_rexml_request.to_s)
      $egg_integrator.send_to_core(xml_to_sa, $egg_integrator.core_in_ufebs_jpm.first[:correlation_id])
      $log_egg.write_to_browser("Изменили в XML TransportGUID и отправили в ядро")
      $log_egg.write_to_log(functional, "Изменили в XML TransportGUID и отправили в ядро", xml_to_sa)
    end
    $egg_integrator.core_in_ufebs_jpm.clear
  end

  def payment
    sleep 1.5
    begin
      count = 1
      until @result["payment"] == "true" or count > @try_count
        xml_name = 'Payment'
        functional = "#{@functional}. #{xml_name}. Попытка #{count}"
        $log_egg.write_to_log(functional, "Начали проверку в #{Time.now.strftime('%H-%M-%S')}", "#{@menu_name} #{xml_name}")
        $log_egg.write_to_browser("#{puts_line_egg}")
        $log_egg.write_to_browser("Начали проверку: #{@menu_name}. #{xml_name}. Попытка #{count}")
        $log_egg.write_to_browser("Пытаемся найти XML в БД")
        $log_egg.write_to_log(functional, "Пытаемся найти XML в БД")
        xml = Xml.where(xml_name: xml_name, category_id: @category.id).first
        raise @not_find_xml if xml.nil?
        $log_egg.write_to_log(functional, "Получили xml", "Получили xml: #{xml.xml_name}\n#{xml.xml_text}")
        xml_rexml = Document.new(xml.xml_text)
        xml_rexml.elements["//rev:OrderID"].text = @orderid
        FileUtils.rm_r @dir_inbound if File.directory?(@dir_inbound)# Чистим каталог для получения
        $log_egg.write_to_browser("Удалили каталог #{@dir_inbound}...")
        $log_egg.write_to_log(functional, "Удаляем каталог для отправления", "Удалили каталог #{@dir_inbound}")
        File.open("#{@dir_outbound}/#{xml_name}.xml", 'w'){ |file| file.write xml_rexml.to_s }
        $log_egg.write_to_browser("Положили запрос в каталог #{@dir_outbound}")
        $log_egg.write_to_log(functional, "Подкладываем запрос #{xml_name}.xml", "Положили запрос в каталог #{@dir_outbound}:\n#{xml_rexml.to_s}")
        change_transportguid(functional, '00000000-0000-0000-0000-000000000000') # Перехватываем сообщение до ядра и меняем TransportGUID на значение из заглушки
        answer = get_file_body(@dir_inbound)
        if answer.size == 0
          @result["payment"] = "false"
          $log_egg.write_to_browser("Проверка не пройдена! Не получили ответ от eGG")
          $log_egg.write_to_log(functional, "Проверка не пройдена!", "Не получили ответ от eGG")
          colorize_egg(@egg_version, @menu_name, @fail_menu_color)
        else
          $log_egg.write_to_browser("Получили ответ из каталога #{@dir_inbound}!")
          $log_egg.write_to_log(functional, "Ответ от eGG!", "Done! Получили ответ из каталога #{@dir_inbound}!")
          if answer.include?(@expected_result)
            @result["payment"] = "true"
            $log_egg.write_to_browser("Проверка пройдена!")
            $log_egg.write_to_log(functional, "Проверка пройдена!", "Done! Ответ содержит в себе значение: #{@expected_result}\n#{answer}")
            colorize_egg(@egg_version, @menu_name, @pass_menu_color) if !@result.has_value?("false")
          else
            @result["payment"] = "false"
            $log_egg.write_to_browser("Проверка не пройдена! Ответ не содержит в себе значение: #{@expected_result}")
            $log_egg.write_to_log(functional, "Проверка не пройдена!", "Ответ не содержит в себе значение: #{@expected_result}\n#{answer}")
            colorize_egg(@egg_version, @menu_name, @fail_menu_color)
          end
        end
        count +=1
      end
    rescue Exception => msg
      @result["payment"] = "false"
      $log_egg.write_to_browser("Ошибка! #{msg}")
      $log_egg.write_to_log(functional, "Ошибка!", "Ошибка! #{msg}\n#{msg.backtrace.join("\n")}")
      colorize_egg(@egg_version, @menu_name, @fail_menu_color)
    end
  end

  def payment_cancellation
    sleep 1.5
    begin
      count = 1
      until @result["payment_cancellation"] == "true" or count > @try_count
        xml_name = 'GIS_ZKH_Payment_Cancellation'
        functional = "#{@functional}. #{xml_name}. Попытка #{count}"
        $log_egg.write_to_log(functional, "Начали проверку в #{Time.now.strftime('%H-%M-%S')}", "#{@menu_name} #{xml_name}")
        $log_egg.write_to_browser("#{puts_line_egg}")
        $log_egg.write_to_browser("Начали проверку: #{@menu_name}. #{xml_name}. Попытка #{count}")
        $log_egg.write_to_browser("Пытаемся найти XML в БД")
        $log_egg.write_to_log(functional, "Пытаемся найти XML в БД")
        xml = Xml.where(xml_name: xml_name, category_id: @category.id).first
        raise @not_find_xml if xml.nil?
        $log_egg.write_to_log(functional, "Получили xml", "Получили xml: #{xml.xml_name}\n#{xml.xml_text}")
        xml_rexml = Document.new(xml.xml_text)
        xml_rexml.elements["//rev:OrderID"].text = @orderid
        FileUtils.rm_r @dir_inbound if File.directory?(@dir_inbound)# Чистим каталог для получения
        $log_egg.write_to_browser("Удалили каталог #{@dir_inbound}...")
        $log_egg.write_to_log(functional, "Удаляем каталог для отправления", "Удалили каталог #{@dir_inbound}")
        File.open("#{@dir_outbound}/#{xml_name}.xml", 'w'){ |file| file.write xml_rexml.to_s }
        $log_egg.write_to_browser("Положили запрос в каталог #{@dir_outbound}")
        $log_egg.write_to_log(functional, "Подкладываем запрос #{xml_name}.xml", "Положили запрос в каталог #{@dir_outbound}:\n#{xml_rexml.to_s}")
        change_transportguid(functional, '00000000-0000-0000-0000-000000000000') # Перехватываем сообщение до ядра и меняем TransportGUID на значение из заглушки
        answer = get_file_body(@dir_inbound)
        if answer.size == 0
          @result["payment_cancellation"] = "false"
          $log_egg.write_to_browser("Проверка не пройдена! Не получили ответ от eGG")
          $log_egg.write_to_log(functional, "Проверка не пройдена!", "Не получили ответ от eGG")
          colorize_egg(@egg_version, @menu_name, @fail_menu_color)
        else
          expected_result_cancellation = 'Cancellation' # Текст, который должен быть в XML, если она успешна
          $log_egg.write_to_browser("Получили ответ из каталога #{@dir_inbound}!")
          $log_egg.write_to_log(functional, "Ответ от eGG!", "Done! Получили ответ из каталога #{@dir_inbound}!")
          if answer.include?(@expected_result) and answer.include?(expected_result_cancellation)
            @result["payment_cancellation"] = "true"
            $log_egg.write_to_browser("Проверка пройдена!")
            $log_egg.write_to_log(functional, "Проверка пройдена!", "Done! Ответ содержит в себе значения: #{@expected_result} и #{expected_result_cancellation}\n#{answer}")
            colorize_egg(@egg_version, @menu_name, @pass_menu_color) if !@result.has_value?("false")
          else
            @result["payment_cancellation"] = "false"
            $log_egg.write_to_browser("Проверка не пройдена! Ответ не содержит в себе значения: #{@expected_result} и #{expected_result_cancellation}")
            $log_egg.write_to_log(functional, "Проверка не пройдена!", "Ответ не содержит в себе значения: #{@expected_result} и #{expected_result_cancellation}\n#{answer}")
            colorize_egg(@egg_version, @menu_name, @fail_menu_color)
          end
        end
        count +=1
      end
    rescue Exception => msg
      @result["payment_cancellation"] = "false"
      $log_egg.write_to_browser("Ошибка! #{msg}")
      $log_egg.write_to_log(functional, "Ошибка!", "Ошибка! #{msg}\n#{msg.backtrace.join("\n")}")
      colorize_egg(@egg_version, @menu_name, @fail_menu_color)
    end
  end

end