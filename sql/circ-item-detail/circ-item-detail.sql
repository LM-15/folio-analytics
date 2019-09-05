/* FIELDS INCLUDED IN SAMPLE:
    date range (filter?)
    owning library
    charge date
    item barcode
    title
    holdings location
    display call no
    item enum
    copy number
    patron group name

EXTRA FIELDS MENTIONED IN PROTOTYPE DESCRIPTION
    loan type
    material type
    reserves

Note: no aggregation
FILTERS: loan date, item status
*/

/* Change the lines below to adjust the date and item status filters */
WITH parameters AS (
    SELECT
        DATE('2000-01-01') AS start_date,
        DATE('2020-01-01') AS end_date,
        'Checked out'::varchar AS item_status_filter
)
SELECT
    (SELECT start_date::varchar FROM parameters) ||
    ' to '::varchar ||
    (SELECT end_date::varchar FROM parameters) AS date_range,
    inst.name AS institution_name,
    ipl.name AS item_perm_location,
    l.loan_date AS loan_date,
    h.shelving_title AS holdings_shelving_title,
    h.call_number AS holdings_call_number,
    i.item_level_call_number AS item_call_number,
    i.barcode AS item_barcode,
    i.enumeration AS item_enumeration,
    /* returns "copyNumbers" as an array in JSON syntax */
    json_extract_path_text(i.data, 'copyNumbers') AS copy_numbers,
    /* alternative: code below converts elements of "copyNumbers" to
       pipe-delimited list. does not work on Redshift. */
    /*array_to_string(
        ARRAY[
            json_array_elements_text(
                json_extract_path(i.data, 'copyNumbers'))],'|') AS copy_numbers,*/
    json_extract_path_text(i.data, 'status', 'name') AS item_status_name,
    m.name AS material_type,
    g.group AS group_name

FROM (
    SELECT
        id,
        user_id,
        item_id,
        loan_date
    FROM loans
    WHERE
        loan_date BETWEEN (SELECT start_date FROM parameters)
        AND (SELECT end_date FROM parameters)
) AS l

/* Using INNER JOIN because we want to enforce the item status filter */
INNER JOIN (
    SELECT
        id,
        item_level_call_number,
        barcode,
        enumeration,
        data,
        holdings_record_id,
        permanent_location_id,
        material_type_id
    FROM items
    WHERE json_extract_path_text(items.data, 'status', 'name') =
        (SELECT item_status_filter FROM parameters)
) AS i
    ON l.item_id = i.id

LEFT JOIN users AS u
    ON l.user_id = u.id

LEFT JOIN groups AS g
    ON u.patron_group = g.id

LEFT JOIN holdings AS h
    ON i.holdings_record_id = h.id

LEFT JOIN locations AS ipl
    ON i.permanent_location_id = ipl.id

LEFT JOIN material_types AS m
    ON i.material_type_id = m.id

LEFT JOIN institutions AS inst
    ON ipl.institution_id = inst.id

ORDER BY inst.name, ipl.name, l.loan_date
;
