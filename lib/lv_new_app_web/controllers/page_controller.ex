defmodule LvNewAppWeb.PageController do
  use LvNewAppWeb, :controller
  use PrintDecorator
  alias Decimal

  # @decorate print()
  def home(conn, _params) do
    data =
      query()
      |> Enum.map(fn z ->
        %{
          contract_id: z.contract_id,
          tenant_id: z.tenant_id,
          floor_id: z.floor_id,
          unit_id: z.unit_id,
          available_status: "Dummy Data (for now)",
          start_date: z.start_date,
          end_date: z.end_date,
          lease: current_or_future(z),
          activation_date: z.activation_date,
          deactivation_date: z.deactivation_date,
          gross_area: z.gross_area
        }
      end)

    future = future_contracts(data) |> IO.inspect(label: "future")
    to_remove = extract_ids_to_remove(future) |> IO.inspect(label: "remove")

    new_data =
      remove_processed_maps(data, to_remove)
      |> Enum.reject(&(&1.lease == :past))
      |> IO.inspect(label: "future")

    pass_1_data = get_pass_one_data(new_data)

    IO.inspect(pass_1_data ++ future)

    render(conn, :home, layout: false)
  end

  defp get_pass_one_data(new_data) do
    Enum.group_by(new_data, &{&1.floor_id, &1.contract_id, &1.tenant_id})
    |> Enum.map(fn {x, y} ->
      {floor, contract, tenant} = x
      space_ids = Enum.map(y, & &1.unit_id) |> Enum.uniq()

      spaces =
        Enum.map(
          y,
          &%{
            gross_area: &1.gross_area,
            activation_date: &1.activation_date,
            deactivation_date: &1.deactivation_date
          }
        )
        |> Enum.uniq()

      Enum.map(y, fn z ->
        %{
          contract_ids: [contract],
          tenant_ids: [tenant],
          floor_id: floor,
          unit_ids: space_ids,
          area: get_filtered_floor_area(spaces, ~D[2023-01-11]),
          available_status: "Dummy Data (for now)",
          start_date: z.start_date,
          end_date: z.end_date
        }
      end)
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp remove_processed_maps(data, []) do
    data
  end

  defp remove_processed_maps(data, to_remove) do
    for {fid, uid} <- to_remove do
      Enum.reject(data, fn x -> fid == x.floor_id and uid == x.unit_id end)
    end
    |> List.flatten()
    |> Enum.uniq()
  end

  defp extract_ids_to_remove(list) do
    Enum.map(list, fn x ->
      case x do
        %{future: %{floor_id: f, unit_ids: u}} -> {f, u}
        %{current: %{floor_id: f, unit_ids: u}} -> {f, u}
      end
    end)
  end

  defp future_contracts(data) do
    Enum.group_by(data, & &1.floor_id)
    |> Enum.map(fn {x, y} ->
      Enum.group_by(y, & &1.unit_id)
      |> Enum.map(fn {a, b} ->
        future? = if :future in Enum.map(b, & &1.lease), do: true, else: false

        if future? do
          Enum.map(b, fn z ->
            spaces = [
              %{
                gross_area: z.gross_area,
                activation_date: z.activation_date,
                deactivation_date: z.deactivation_date
              }
            ]

            case z.lease do
              :current ->
                %{
                  current: %{
                    contract_ids: z.contract_id,
                    tenant_ids: z.tenant_id,
                    floor_id: z.floor_id,
                    unit_ids: z.unit_id,
                    area: get_filtered_floor_area(spaces, ~D[2023-01-11]),
                    available_status: "Dummy Data (for now)"
                  }
                }

              :future ->
                %{
                  future: %{
                    contract_ids: z.contract_id,
                    tenant_ids: z.tenant_id,
                    floor_id: z.floor_id,
                    unit_ids: z.unit_id,
                    area: get_filtered_floor_area(spaces, ~D[2023-01-11]),
                    available_status: "Dummy Data (for now)"
                  }
                }

              _ ->
                nil
            end
          end)
        else
          nil
        end
      end)
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil(&1))
  end

  defp get_filtered_floor_area(spaces, date) do
    date_today = DateTime.utc_now()

    Enum.reduce(spaces, Decimal.new(0), fn %{
                                             gross_area: gross_area,
                                             activation_date: activation_date,
                                             deactivation_date: deactivation_date
                                           },
                                           acc ->
      # Check if space is activated or not
      if Date.compare(date, activation_date) in [:gt, :eq] and
           Date.compare(date_today, activation_date) in [:gt, :eq] and
           (is_nil(deactivation_date) or
              (not is_nil(deactivation_date) and
                 Date.compare(date_today, deactivation_date) in [:lt])) do
        Decimal.add(gross_area, acc)
      else
        acc
      end
    end)
  end

  defp current_or_future(map) do
    now = NaiveDateTime.utc_now()

    start_date = Date.compare(map.start_date, now)
    end_date = Date.compare(map.end_date, now)

    cond do
      (start_date == :lt or start_date == :eq) and end_date == :gt -> :current
      start_date == :gt -> :future
      true -> :past
    end
  end

  defp query do
    [
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "1a7be3e8-c699-4a23-8c3d-d4374f8ac6b4"
      },
      %{
        activation_date: ~D[2022-11-18],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "5959a70b-1e3d-4e02-a420-7160254bd823"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "3b9e1790-96ec-4295-a34d-e2e94eb7c861"
      },
      %{
        activation_date: ~D[2022-11-06],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "4a8259b1-1f03-4546-9b79-87d58eecce62"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: ~D[2022-11-13],
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10099"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "155baf28-585d-4eea-bf7e-dfca1dc0f693"
      },
      %{
        activation_date: ~D[2022-11-06],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "e61b4aea-837f-4f07-8df3-4bae9837fa0a"
      },
      %{
        activation_date: ~D[2022-11-29],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10088"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "52e67922-fef1-4f5c-ae2f-ba51942570e5"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10077"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "b514bfad-9b52-4329-82b0-75de43e2ea56"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "eee96d01-0a7c-449e-ba0c-99291f9522a6"
      },
      %{
        activation_date: ~D[2012-11-30],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "32ed1bb1-2425-4cd7-9b69-bf1367f1d726"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "f0018779-266f-4020-b4a2-ba4c43719494"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "aec46156-f3a7-4900-9957-36575de17b3c",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "39ca3778-b099-4079-9bca-bb6d136e654a"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "2064574e-1678-4d3b-a85c-951153471e90",
        deactivation_date: nil,
        end_date: ~D[2023-06-30],
        floor_id: "aec46156-f3a7-4900-9957-36575de17b3c",
        gross_area: Decimal.new("100"),
        start_date: ~D[2023-01-01],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "688f9555-510a-4cc6-887f-e81ffeba8230"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "1a7be3e8-c699-4a23-8c3d-d4374f8ac6b4"
      },
      %{
        activation_date: ~D[2022-11-18],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "5959a70b-1e3d-4e02-a420-7160254bd823"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "3b9e1790-96ec-4295-a34d-e2e94eb7c861"
      },
      %{
        activation_date: ~D[2022-11-06],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "4a8259b1-1f03-4546-9b79-87d58eecce62"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: ~D[2022-11-13],
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10099"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "155baf28-585d-4eea-bf7e-dfca1dc0f693"
      },
      %{
        activation_date: ~D[2022-11-06],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "e61b4aea-837f-4f07-8df3-4bae9837fa0a"
      },
      %{
        activation_date: ~D[2022-11-29],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10088"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "52e67922-fef1-4f5c-ae2f-ba51942570e5"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10077"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "b514bfad-9b52-4329-82b0-75de43e2ea56"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "eee96d01-0a7c-449e-ba0c-99291f9522a6"
      },
      %{
        activation_date: ~D[2012-11-30],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "32ed1bb1-2425-4cd7-9b69-bf1367f1d726"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "f0018779-266f-4020-b4a2-ba4c43719494"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "aec46156-f3a7-4900-9957-36575de17b3c",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "39ca3778-b099-4079-9bca-bb6d136e654a"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "0031c35f-6eb4-4c47-9894-aa7a351de793",
        deactivation_date: nil,
        end_date: ~D[2024-02-16],
        floor_id: "aec46156-f3a7-4900-9957-36575de17b3c",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-13],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "688f9555-510a-4cc6-887f-e81ffeba8230"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "1a7be3e8-c699-4a23-8c3d-d4374f8ac6b4"
      },
      %{
        activation_date: ~D[2022-11-18],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "5959a70b-1e3d-4e02-a420-7160254bd823"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "3b9e1790-96ec-4295-a34d-e2e94eb7c861"
      },
      %{
        activation_date: ~D[2022-11-06],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "4a8259b1-1f03-4546-9b79-87d58eecce62"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: ~D[2022-11-13],
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10099"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "155baf28-585d-4eea-bf7e-dfca1dc0f693"
      },
      %{
        activation_date: ~D[2022-11-06],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "e61b4aea-837f-4f07-8df3-4bae9837fa0a"
      },
      %{
        activation_date: ~D[2022-11-29],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10088"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "52e67922-fef1-4f5c-ae2f-ba51942570e5"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("10077"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "b514bfad-9b52-4329-82b0-75de43e2ea56"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "eee96d01-0a7c-449e-ba0c-99291f9522a6"
      },
      %{
        activation_date: ~D[2012-11-30],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "bee806c9-4ffb-4811-86b4-86c7dc3e01ed",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "32ed1bb1-2425-4cd7-9b69-bf1367f1d726"
      },
      %{
        activation_date: ~D[2022-11-09],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "48bcf1ce-fc5e-4e1b-adb0-ecad9982d510",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "f0018779-266f-4020-b4a2-ba4c43719494"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "aec46156-f3a7-4900-9957-36575de17b3c",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "39ca3778-b099-4079-9bca-bb6d136e654a"
      },
      %{
        activation_date: ~D[2022-11-04],
        contract_id: "f3043069-0923-4988-a5fa-d4dc89013869",
        deactivation_date: nil,
        end_date: ~D[2023-01-31],
        floor_id: "aec46156-f3a7-4900-9957-36575de17b3c",
        gross_area: Decimal.new("100"),
        start_date: ~D[2022-11-29],
        tenant_id: "6e9f3330-2d67-4e1f-be34-b1e979f06222",
        unit_id: "688f9555-510a-4cc6-887f-e81ffeba8230"
      }
    ]
  end
end
